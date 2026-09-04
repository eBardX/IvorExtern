// © 2026 John Gary Pusey (see LICENSE.md)

internal import IvorABC
internal import XestiNumbers

// Duration/tuplet/broken-rhythm resolution, ported from upstream's own
// duration-resolution pass: unit note length, broken rhythm, tuplet ratios,
// chord-level length multipliers. Everything here is pure
// `Context`/`ABC.Duration`/`ABC.Event` arithmetic, voice-agnostic — `Walker`
// just hands it whichever voice's `context` is current.
extension ABC.Importer {

    // MARK: Internal Nested Types

    internal struct Rhythm {
    }
}

// MARK: -

extension ABC.Importer.Rhythm {

    // MARK: Internal Instance Methods

    // The duration `context.currentBeatTime` advances by once a pending
    // event commits — a chord occupies the position of its first note, per
    // §4.17.
    internal func advanceDuration(_ event: ABC.Event) -> ABC.Duration {
        switch event {
        case let .chord(chord):
            chord.notes.first?.duration ?? ABC.Duration(numberValue: 0)

        case let .note(note):
            note.duration

        case let .rest(rest):
            rest.duration
        }
    }

    // Returns the `(numerator, denominator)` scaling factor a broken-rhythm
    // marker applies to one side of the flanking pair.
    internal func brokenRhythmFactor(_ marker: ABCBrokenRhythm,
                                     isLeft: Bool) -> (numerator: UInt, denominator: UInt) {
        let factor = _brokenRhythmCharacterCount(marker)
        let denominator = UInt(1) << factor
        let numerator = (UInt(1) << (factor + 1)) - 1
        let isLong: Bool = switch marker {
        case .dotted,
             .doubleDotted,
             .tripleDotted:
            isLeft

        case .reverseDotted,
             .reverseDoubleDotted,
             .reverseTripleDotted:
            !isLeft
        }

        return isLong ? (numerator, denominator) : (1, denominator)
    }

    // Consumes one unit of any pending tuplet scope and/or the pending
    // "right" side of a broken-rhythm pair, returning the combined
    // `(numerator, denominator)` scale to apply to the note/chord/rest about
    // to be built.
    internal func consumedScale(_ context: inout ABC.Importer.Context) -> (numerator: UInt, denominator: UInt) {
        var scale: (numerator: UInt, denominator: UInt) = (1, 1)

        if let tuplet = context.pendingTuplet {
            scale = multiplied(scale, (tuplet.beatCount, tuplet.noteCount))

            let remainingCount = tuplet.remainingCount - 1

            context.pendingTuplet = remainingCount == 0 ? nil : (tuplet.beatCount, tuplet.noteCount, remainingCount)
        }

        if let brokenRhythmRight = context.pendingBrokenRhythmRight {
            scale = multiplied(scale, brokenRhythmRight)
            context.pendingBrokenRhythmRight = nil
        }

        return scale
    }

    // Per §3.1.7, absent an `L:` field, the unit note length is a sixteenth
    // note if the meter's ratio is less than 0.75, and an eighth note
    // otherwise (including free/no meter).
    internal func defaultUnitNoteLength(_ meter: ABCTimeSignature?) -> (numerator: UInt, denominator: UInt) {
        guard let ratio = _meterRatio(meter),
              ratio < 0.75
        else { return (1, 8) }

        return (1, 16)
    }

    internal func measureDuration(_ meter: ABCTimeSignature?) -> ABC.Duration {
        guard let meter
        else { return ABC.Duration(numberValue: Number(numerator: 4, denominator: 4)) }

        switch meter {
        case .common,
             .empty:
            return ABC.Duration(numberValue: Number(numerator: 4, denominator: 4))

        case let .complex(additiveMeter):
            return ABC.Duration(numberValue: Number(numerator: additiveMeter.numerators.reduce(0, +),
                                                    denominator: additiveMeter.denominator))

        case .cut:
            return ABC.Duration(numberValue: Number(numerator: 2, denominator: 2))

        case let .standard(standardMeter):
            return ABC.Duration(numberValue: Number(numerator: standardMeter.numerator,
                                                    denominator: standardMeter.denominator))
        }
    }

    // Merges a tied note/chord pair into one, matching upstream's own tie
    // coalescing: only the *chord-level* tie gates a chord merge — each
    // member note's own tie field is carried through but otherwise unused,
    // exactly as upstream's own coalescing pass treats it.
    internal func merged(_ first: ABC.Event,
                         _ second: ABC.Event) -> ABC.Event? {
        switch (first, second) {
        case let (.chord(chord1), .chord(chord2)):
            guard chord1.tie != nil,
                  chord1.notes.count == chord2.notes.count,
                  zip(chord1.notes, chord2.notes).allSatisfy({ $0.pitch == $1.pitch })
            else { return nil }

            let notes = zip(chord1.notes, chord2.notes).map {
                ABC.Note(duration: $0.duration + $1.duration, pitch: $0.pitch, tie: $1.tie)
            }

            return .chord(ABC.Chord(notes: notes, tie: chord2.tie))

        case let (.note(note1), .note(note2)):
            guard note1.tie != nil,
                  note1.pitch == note2.pitch
            else { return nil }

            return .note(ABC.Note(duration: note1.duration + note2.duration,
                                  pitch: note1.pitch,
                                  tie: note2.tie))

        default:
            return nil
        }
    }

    internal func multiplied(_ lhs: (numerator: UInt, denominator: UInt),
                             _ rhs: (numerator: UInt, denominator: UInt)) -> (numerator: UInt, denominator: UInt) {
        (lhs.numerator * rhs.numerator, lhs.denominator * rhs.denominator)
    }

    // A pending note/chord/rest's duration, rescaled uniformly (used when a
    // broken-rhythm marker retroactively rescales the "left" side of a
    // flanking pair — see `ABC.Importer.Walker`'s type-level comment).
    internal func rescaled(_ event: ABC.Event,
                           by factor: (numerator: UInt, denominator: UInt)) -> ABC.Event {
        switch event {
        case let .chord(chord):
            .chord(ABC.Chord(notes: chord.notes.map { ABC.Note(duration: $0.duration * factor, pitch: $0.pitch, tie: $0.tie) },
                             tie: chord.tie))

        case let .note(note):
            .note(ABC.Note(duration: note.duration * factor, pitch: note.pitch, tie: note.tie))

        case let .rest(rest):
            .rest(ABC.Rest(duration: rest.duration * factor))
        }
    }

    // Returns the fully resolved `(noteCount, beatCount, affectedCount)`
    // components of `tuplet`, with ABC default rules applied for any `nil`
    // component.
    internal func resolvedTuplet(_ tuplet: ABCTuplet,
                                 meter: ABCTimeSignature?) -> (beatCount: UInt, noteCount: UInt, affectedCount: UInt) {
        (tuplet.beatCount ?? _defaultTupletBeatCount(noteCount: tuplet.noteCount,
                                                     isCompound: meter?.isCompound ?? false),
         tuplet.noteCount,
         tuplet.affectedCount ?? tuplet.noteCount)
    }

    // MARK: Private Instance Methods

    // The one/two/three `>`/`<` characters a marker represents —
    // `ABCBrokenRhythm.factor` itself is `internal` to IvorABC and invisible
    // here, so this re-derives the same value from the case itself.
    private func _brokenRhythmCharacterCount(_ marker: ABCBrokenRhythm) -> Int {
        switch marker {
        case .dotted,
             .reverseDotted:
            1

        case .doubleDotted,
             .reverseDoubleDotted:
            2

        case .reverseTripleDotted,
             .tripleDotted:
            3
        }
    }

    // The default beat count ABC assigns a tuplet when none is written
    // explicitly.
    private func _defaultTupletBeatCount(noteCount: UInt,
                                         isCompound: Bool) -> UInt {
        switch noteCount {
        case 2,
             4,
             8:
            3

        case 3,
             6:
            2

        default:
            isCompound ? 3 : 2
        }
    }

    private func _meterRatio(_ meter: ABCTimeSignature?) -> Double? {
        guard let meter
        else { return nil }

        switch meter {
        case .common,
             .cut,
             .empty:
            return 1.0

        case let .complex(additiveMeter):
            return Double(additiveMeter.numerators.reduce(0, +)) / Double(additiveMeter.denominator)

        case let .standard(standardMeter):
            return Double(standardMeter.numerator) / Double(standardMeter.denominator)
        }
    }
}
