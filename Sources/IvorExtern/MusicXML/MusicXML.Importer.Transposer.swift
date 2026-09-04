// © 2026 John Gary Pusey (see LICENSE.md)

internal import IvorMusicXML

// The pitch arithmetic behind sounding-pitch resolution, ported from
// upstream's own pitch transposer: given a written pitch and the
// `<transpose>` active for its staff, returns the pitch that actually
// sounds. `chromatic`
// shifts by semitones, `octaveChange` by whole octaves, and `double` by a
// further octave (below unless `above` is set); `diatonic`, when present,
// fixes the letter-name spelling of the result, and without it a canonical
// sharp spelling is chosen.
extension MusicXML.Importer {

    internal struct Transposer {
    }
}

// MARK: -

extension MusicXML.Importer.Transposer {

    // MARK: Internal Instance Methods

    // Returns the sounding pitch for `pitch` under `transpose`, or `pitch`
    // unchanged when `transpose` is `nil`. Throws `Error.unrepresentablePitch`
    // when the result falls outside the representable octave range 0…9.
    // `context` labels the offending element.
    internal func transpose(_ pitch: MXLPitch,
                            by transpose: MXLTranspose?,
                            context: @autoclosure () -> String) throws(MusicXML.Error) -> MXLPitch {
        guard let transpose
        else { return pitch }

        let content = transpose.content
        let octaveShift = content.octaveChange?.intValue ?? 0
        let doubleSemitones = Self._doubleSemitones(content.double)
        let writtenSemitones = Self._semitones(of: pitch)
        let soundingSemitones = writtenSemitones
            + content.chromatic
            + Double(octaveShift * 12)
            + Double(doubleSemitones)

        let spelling = Self._spelling(soundingSemitones: soundingSemitones,
                                      writtenPitch: pitch,
                                      diatonicShift: content.diatonic.map { $0.intValue + octaveShift * 7 + (doubleSemitones / 12) * 7 })

        guard let octave = MXLOctave(uintValue: UInt(spelling.octave))
        else { throw MusicXML.Error.unrepresentablePitch(context()) }

        return MXLPitch(step: spelling.step,
                        alter: spelling.alter == 0 ? nil : spelling.alter,
                        octave: octave)
    }

    // MARK: Private Type Methods

    // `<double>` doubles the music one octave — above when `above` is set,
    // below (the common band/orchestral case) otherwise.
    private static func _doubleSemitones(_ double: MXLDouble?) -> Int {
        guard let double
        else { return 0 }

        return double.isAbove == true ? 12 : -12
    }

    // Splits a floored integer count into a floored quotient/remainder pair,
    // so a negative dividend still yields a remainder in `0..<divisor`
    // (Swift's built-in `/` and `%` truncate toward zero, which would not).
    private static func _floorDivide(_ dividend: Int,
                                     by divisor: Int) -> (quotient: Int, remainder: Int) {
        var quotient = dividend / divisor
        var remainder = dividend % divisor

        if remainder < 0 {
            quotient -= 1
            remainder += divisor
        }

        return (quotient, remainder)
    }

    private static func _index(of step: MXLStep) -> Int {
        switch step {
        case .a:
            5

        case .b:
            6

        case .c:
            0

        case .d:
            1

        case .e:
            2

        case .f:
            3

        case .g:
            4
        }
    }

    private static func _semitone(of step: MXLStep) -> Int {
        switch step {
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

    private static func _semitones(of pitch: MXLPitch) -> MXLSemitones {
        Double(Int(pitch.octave.uintValue) * 12 + _semitone(of: pitch.step)) + (pitch.alter ?? 0)
    }

    // Chooses the step/octave/alter of the sounding pitch. When a diatonic
    // shift is given, it fixes the letter name (and the alter absorbs
    // whatever chromatic remainder, including any microtone, is left over);
    // otherwise a canonical sharp spelling is derived from the pitch class.
    private static func _spelling(soundingSemitones: MXLSemitones,
                                  writtenPitch: MXLPitch,
                                  diatonicShift: Int?) -> (step: MXLStep, octave: Int, alter: MXLSemitones) {
        if let diatonicShift {
            let writtenDiatonic = Int(writtenPitch.octave.uintValue) * 7 + _index(of: writtenPitch.step)
            let (octave, index) = _floorDivide(writtenDiatonic + diatonicShift, by: 7)
            let step = _step(forIndex: index)
            let base = Double(octave * 12 + _semitone(of: step))

            return (step, octave, soundingSemitones - base)
        }

        // Floor to whole semitones for the octave/pitch-class split; any
        // microtone remainder is carried by `alter` via `soundingSemitones`.
        let flooredSemitones = Int(soundingSemitones.rounded(.down))
        let (octave, pitchClass) = _floorDivide(flooredSemitones, by: 12)
        let step = _step(forPitchClass: pitchClass)
        let base = Double(octave * 12 + _semitone(of: step))

        return (step, octave, soundingSemitones - base)
    }

    private static func _step(forIndex index: Int) -> MXLStep {
        switch index {
        case 0:
            .c

        case 1:
            .d

        case 2:
            .e

        case 3:
            .f

        case 4:
            .g

        case 5:
            .a

        default:
            .b
        }
    }

    // The canonical sharp spelling of a pitch class: the alter needed to
    // reach it from `step` is recovered by the caller as
    // `soundingSemitones - base`.
    private static func _step(forPitchClass pitchClass: Int) -> MXLStep {
        switch pitchClass {
        case 0,
             1:
            .c

        case 2,
             3:
            .d

        case 4:
            .e

        case 5,
             6:
            .f

        case 7,
             8:
            .g

        case 9,
             10:
            .a

        default:
            .b
        }
    }
}
