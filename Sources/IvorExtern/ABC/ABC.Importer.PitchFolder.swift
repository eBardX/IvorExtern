// © 2026 John Gary Pusey (see LICENSE.md)

internal import IvorABC

private import XestiTools

// Written- and sounding-pitch resolution, ported from upstream's own two
// pitch-resolution passes: written-pitch resolution (key signature plus
// measure-local accidental propagation, §4.6 — runs unconditionally, for
// every note) and sounding-pitch folding (`transpose=`/`octave=`/ottava plus
// a fixed sharps-only respelling — this importer has always walked an
// already playback-optimized result, so folding is baseline behavior, not
// new).
extension ABC.Importer {

    // MARK: Internal Nested Types

    internal struct PitchFolder {
    }
}

// MARK: -

extension ABC.Importer.PitchFolder {

    // MARK: Internal Instance Methods

    // The clef an in-stream key signature carries, if any — updates the
    // active clef used for sounding-pitch folding.
    internal func clef(from keySignature: ABCKeySignature) -> ABCClef? {
        switch keySignature {
        case let .clefOnly(clef):
            clef

        case let .standard(standard):
            standard.clef

        case .empty,
             .highlandPipes,
             .highlandPipesPreset:
            nil
        }
    }

    // `absolute = octave*12 + semitone(letter) + delta(accidental)`;
    // `shift = transpose + octave*12 + ottava`; `folded = absolute + shift`.
    // A `nil` clef folds with an all-zero shift — the pitch is unaffected in
    // absolute pitch, but is still uniformly respelled via the fixed
    // sharps-only table.
    internal func foldedPitch(_ pitch: ABCPitch,
                              _ clef: ABCClef?) throws(ABC.Error) -> ABCPitch {
        let absolute = Int(pitch.octave.uintValue) * 12
                     + _semitone(for: pitch.letter)
                     + _delta(for: pitch.accidental)

        guard let folded = _foldedSemitone(absolute, clef)
        else { throw ABC.Error.unrepresentablePitch("pitch fold overflowed (clef transpose/octave too large)") }

        guard (0...119).contains(folded)
        else { throw ABC.Error.unrepresentablePitch("pitch folded to \(folded) semitones from C0, outside representable octaves 0...9") }

        let (letter, accidental) = _respelled(folded % 12)
        let octave = ABCPitch.Octave(uintValue: UInt(folded / 12)).require()

        return ABCPitch(letter: letter,
                        accidental: accidental,
                        octave: octave)
    }

    internal func resolvedAccidental(for pitch: ABCPitch,
                                     _ context: ABC.Importer.Context) -> ABCPitch.Accidental {
        if pitch.accidental != .omitted {
            return pitch.accidental
        }

        if let barAccidental = context.barAccidentals[pitch.letter] {
            return barAccidental
        }

        return context.keyAccidentals[pitch.letter] ?? .natural
    }

    // Resolves `pitch`'s effective accidental against `context` (recording
    // any written accidental into `barAccidentals` so it propagates to
    // later notes of the same letter within the bar).
    internal func resolvedWrittenPitch(_ pitch: ABCPitch,
                                       _ context: inout ABC.Importer.Context) -> ABCPitch {
        let accidental = resolvedAccidental(for: pitch, context)

        if pitch.accidental != .omitted {
            context.barAccidentals[pitch.letter] = pitch.accidental
        }

        return ABCPitch(letter: pitch.letter,
                        accidental: accidental,
                        octave: pitch.octave)
    }

    // MARK: Private Instance Methods

    private func _delta(for accidental: ABCPitch.Accidental) -> Int {
        switch accidental {
        case .doubleFlat:
            -2

        case .doubleSharp:
            2

        case .flat:
            -1

        case .natural,
             .omitted:
            0

        case .sharp:
            1
        }
    }

    // Computes `absolute + transpose + octave*12 + ottava` with
    // overflow-reporting arithmetic throughout, returning `nil` on overflow
    // instead of trapping.
    private func _foldedSemitone(_ absolute: Int,
                                 _ clef: ABCClef?) -> Int? {
        let (octaveShift, octaveOverflow) = (clef?.octave ?? 0).multipliedReportingOverflow(by: 12)

        guard !octaveOverflow
        else { return nil }

        let (shift, shiftOverflow) = (clef?.transpose ?? 0).addingReportingOverflow(octaveShift)

        guard !shiftOverflow
        else { return nil }

        let (withOttava, ottavaOverflow) = shift.addingReportingOverflow(_ottavaShift(clef?.ottava))

        guard !ottavaOverflow
        else { return nil }

        let (folded, foldedOverflow) = absolute.addingReportingOverflow(withOttava)

        return foldedOverflow ? nil : folded
    }

    private func _ottavaShift(_ ottava: ABCClef.Ottava?) -> Int {
        switch ottava {
        case .alta:
            12

        case .bassa:
            -12

        case nil:
            0
        }
    }

    // A fixed sharps-only respelling of a semitone (0...11) within an
    // octave. Sounding pitch is all a literal player cares about, so
    // there's no ambiguity to resolve by preferring flats in some contexts.
    private func _respelled(_ semitone: Int) -> (ABCPitch.Letter, ABCPitch.Accidental) {
        switch semitone {
        case 0:
            (.c, .natural)

        case 1:
            (.c, .sharp)

        case 2:
            (.d, .natural)

        case 3:
            (.d, .sharp)

        case 4:
            (.e, .natural)

        case 5:
            (.f, .natural)

        case 6:
            (.f, .sharp)

        case 7:
            (.g, .natural)

        case 8:
            (.g, .sharp)

        case 9:
            (.a, .natural)

        case 10:
            (.a, .sharp)

        default:
            (.b, .natural)    // 11
        }
    }

    private func _semitone(for letter: ABCPitch.Letter) -> Int {
        switch letter {
        case .a:
            9

        case .b:
            11

        case .c:
            0

        case .d:
            2

        case .e:
            4

        case .f:
            5

        case .g:
            7
        }
    }
}
