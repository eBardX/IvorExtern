// © 2026 John Gary Pusey (see LICENSE.md)

internal import IvorABC
internal import IvorModel
internal import IvorTiming
internal import IvorTuning
internal import XestiNumbers
internal import XestiTools

// Writing ornamentation as ABC: grace groups in braces, trills and mordents by name, abcm2ps's
// tremolo marks, `!arpeggio!` and `!fermata!`. What ABC can't hold is dropped and reported
// (see `ExternWarning.Kind`).
extension ABC.Exporter {

    // MARK: Internal Type Methods

    internal static func abcDecoration(_ name: String) -> ABCSymbol {
        .decoration(ABCDecoration(name: ABCDecoration.Name(stringValue: name).require()).require())
    }

    //
    // The grace group before the attacked tones: the figure on their lowest tone, after any
    // figure carried from the note before (ABC has no figure after a note). A lone grace note's
    // unit is an eighth, each of a group's a sixteenth, as the renderers read them; grace chords
    // are written in brackets inside the braces. Executions are dropped.
    //
    internal static func graceSymbols(_ tones: [ExportTone],
                                      carried: NoteTable<BeatTime, Pitch>.GraceFigure?,
                                      accidentals: inout AccidentalState,
                                      report: (ExternWarning.Kind) -> Void) throws(ABC.Error) -> [ABCSymbol] {
        let own = tones.min { $0.pitch < $1.pitch }?.ornamentation?.graceBefore ?? tones.lazy.compactMap(\.ornamentation?.graceBefore).first
        let events = (carried?.events ?? []) + (own?.events ?? [])

        guard !events.isEmpty
        else { return [] }

        let isTied = own?.isTiedToMainNote ?? false

        if [carried?.execution, own?.execution].contains(where: { !($0?.isEmpty ?? true) })
           || events.contains(where: { !($0.execution?.isEmpty ?? true) }) {
            report(.droppedExecution)
        }

        let unit = Number(numerator: 1, denominator: events.count == 1 ? 8 : 16)
        var elements: [ABCGraceNotes.Element] = []

        for (index, event) in events.enumerated() {
            let length = _graceLength(event.length.map { $0.duration.numberValue / unit })
            let tie: ABCTie? = isTied && index == events.count - 1 ? .regular : nil
            var notes: [ABCNote] = []

            for pitch in event.pitches {
                try notes.append(ABCNote(pitch: accidentals.abcPitch(for: pitch),
                                         length: event.pitches.count == 1 ? length : unitLength,
                                         tie: event.pitches.count == 1 ? tie : nil))
            }

            if notes.count == 1 {
                elements.append(.note(notes[0]))
            } else if let chord = ABCChord(notes: notes, length: length, tie: tie) {
                elements.append(.chord(chord))
            }
        }

        guard let graceNotes = ABCGraceNotes(elements: elements,
                                             isSlashed: own?.isSlashed ?? carried?.isSlashed ?? false)
        else { return [] }

        return [.graceNotes(graceNotes)]
    }

    // A non-power-of-2 denominator has no plain ABC spelling (`ABCLength`
    // requires one), so the odd factor left after removing every factor of
    // 2 becomes the tuplet's `noteCount`, always paired with an explicit
    // `beatCount` of 2 chosen by this exporter — since both the tuplet
    // marker and the written length it precedes are emitted together here,
    // there's no need to match ABC's own note-count-keyed default beat
    // count table (§4.13); only internal consistency with the written
    // length below matters. `affectedCount` is always 1: every event gets
    // its own tuplet marker rather than trying to merge a run of equal
    // durations into one grouped marker, so a chord and a following single
    // note each scale independently even when they'd share a marker in
    // idiomatic hand-written ABC.
    internal static func lengthAndTuplet(for duration: BeatDuration) throws(ABC.Error) -> (length: ABCLength, tuplet: ABCTuplet?) {
        // In units of the `L:1/4` this exporter always writes.
        let numberValue = duration.numberValue * 4

        guard numberValue.isRational
        else { throw ABC.Error.unrepresentableDuration("\(duration)") }

        let numerator = numberValue.numerator.uintValue
        let denominator = numberValue.denominator.uintValue

        guard numerator > 0
        else { throw ABC.Error.unrepresentableDuration("\(duration)") }

        var oddPart = denominator

        while oddPart.isMultiple(of: 2) {
            oddPart /= 2
        }

        if oddPart == 1 {
            guard let length = ABCLength(numerator: numerator,
                                         denominator: denominator)
            else { throw ABC.Error.unrepresentableDuration("\(duration)") }

            return (length, nil)
        }

        guard (2...9).contains(oddPart),
              let tuplet = ABCTuplet(noteCount: oddPart,
                                     beatCount: 2,
                                     affectedCount: 1)
        else { throw ABC.Error.unrepresentableDuration("\(duration)") }

        // `ABCLength.init?` requires the *raw* denominator it's given to
        // already be a power of 2 — it validates before reducing, so a
        // denominator that would only become one after gcd reduction still
        // fails. Written length = duration × noteCount / beatCount =
        // (numerator / (oddPart × pow2Part)) × (oddPart / 2); the `oddPart`
        // introduced by the tuplet scale exactly cancels the one just
        // divided out of `denominator`, leaving `numerator` unchanged over
        // a denominator of `pow2Part × 2` — already a power of 2 by
        // construction, with no reduction required.
        let pow2Part = denominator / oddPart

        guard let length = ABCLength(numerator: numerator,
                                     denominator: pow2Part * 2)
        else { throw ABC.Error.unrepresentableDuration("\(duration)") }

        return (length, tuplet)
    }

    //
    // The decorations for the attacked tones' trill or mordent (named by its partner's side), a
    // single tremolo's marks (its strokes less the written note's flags), the roll and the
    // fermata — or a fermata mark starting here. An ornament with no sign is dropped, as are
    // executions, a written partner, and a roll's direction; a roll shared with another part is
    // written in each, and reported once, by the first part it's in.
    //
    internal static func ornamentSymbols(_ tones: [ExportTone],
                                         duration: BeatDuration,
                                         hasFermataMark: Bool,
                                         sharedRolls: [RollKey: Int],
                                         partIndex: Int,
                                         report: (ExternWarning.Kind) -> Void) -> [ABCSymbol] {
        var symbols: [ABCSymbol] = []

        if let ornament = tones.lazy.compactMap(\.ornamentation?.ornament).first {
            let hasWrittenPartner = if case .step(_, _?) = ornament.partner { true } else { false }

            if !(ornament.execution?.isEmpty ?? true) || hasWrittenPartner {
                report(.droppedExecution)
            }

            switch (ornament.sign, ornament.partner) {
            case (.trill, _):
                symbols.append(abcDecoration("trill"))

            case (.mordent, .step(.below, _)):
                symbols.append(abcDecoration("lowermordent"))

            case (.mordent, _):
                symbols.append(abcDecoration("uppermordent"))

            case let (.tremolo(.measured(strokes)), .repeat):
                let marks = min(3, max(1, Int(strokes.uintValue) - Int(convertToFlagCount(duration))))

                symbols.append(abcDecoration(String(repeating: "/", count: marks)))

            case (.tremolo(.unmeasured), .repeat):
                symbols.append(abcDecoration("///"))

            case (.tremolo, _):
                break

            case (nil, _):
                report(.droppedOrnament)
            }
        }

        if let tone = tones.first(where: { $0.ornamentation?.arpeggio != nil }),
           let arpeggio = tone.ornamentation?.arpeggio {
            symbols.append(abcDecoration("arpeggio"))

            if sharedRolls[RollKey(attack: tone.attack, group: arpeggio.group)] == partIndex {
                report(.splitArpeggio)
            }

            if arpeggio.direction == .down || !(arpeggio.execution?.isEmpty ?? true) {
                report(.droppedExecution)
            }
        }

        if let fermata = tones.lazy.compactMap(\.ornamentation?.fermata).first {
            symbols.append(abcDecoration("fermata"))

            if fermata.execution != nil {
                report(.droppedExecution)
            }
        } else if hasFermataMark {
            symbols.append(abcDecoration("fermata"))
        }

        return symbols
    }

    //
    // A note alone in its slice with a two-note tremolo, written back as the two halves its
    // import joined, with `!tremN!` between them (N its strokes less each half's flags); `nil`
    // for anything else, or a half ABC can't write without a tuplet.
    //
    internal static func twoNoteTremoloSymbols(_ slice: ExportSlice,
                                               duration: BeatDuration,
                                               accidentals: inout AccidentalState) throws(ABC.Error) -> [ABCSymbol]? {
        guard slice.tones.count == 1,
              let tone = slice.tones.first,
              tone.attack == slice.start,
              !slice.continues(tone),
              case let .tremolo(kind)? = tone.ornamentation?.ornament?.sign,
              case let .pitches(partners)? = tone.ornamentation?.ornament?.partner,
              let partner = partners.first,
              let half = duration.divided(by: 2)
        else { return nil }

        let (length, tuplet) = try lengthAndTuplet(for: half)

        guard tuplet == nil
        else { return nil }

        let marks = switch kind {
        case let .measured(strokes):
            min(4, max(1, Int(strokes.uintValue) - Int(convertToFlagCount(half))))

        case .unmeasured:
            3
        }

        return try [.note(ABCNote(pitch: accidentals.abcPitch(for: tone.pitch), length: length, tie: nil)),
                    abcDecoration("trem\(marks)"),
                    .note(ABCNote(pitch: accidentals.abcPitch(for: partner), length: length, tie: nil))]
    }

    // MARK: Private Type Properties

    private static let unitLength = ABCLength(numerator: 1, denominator: 1).require()

    // MARK: Private Type Methods

    //
    // A grace event's length in units, if ABC can write it; else the unit.
    //
    private static func _graceLength(_ units: Number?) -> ABCLength {
        guard let units,
              units.isRational,
              let numerator = UInt(exactly: units.numerator.intValue),
              let denominator = UInt(exactly: units.denominator.intValue),
              let length = ABCLength(numerator: numerator, denominator: denominator)
        else { return unitLength }

        return length
    }
}
