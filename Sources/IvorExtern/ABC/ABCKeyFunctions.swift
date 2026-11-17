// © 2026 John Gary Pusey (see LICENSE.md)

internal import IvorABC
internal import IvorTuning

private import XestiTools

// MARK: Internal Functions

// The `K:` field for a key signature, or `K:C` for none. A diatonic signature
// is written as its tonic in `mode` (`K:Bm`, `K:Edor`), or as its major key
// without a mode; one with no sharps or flats and the mode "none" is
// `K:none`. A custom signature is written as `K:C exp` with its accidentals,
// in canonical order (`K:C exp _b ^f`), so its meaning doesn't depend on
// any key's own.
internal func convertToABCKeySignature(_ keySignature: KeySignature?,
                                       mode: String?) -> ABCKeySignature {
    guard let keySignature
    else { return cMajor }

    if keySignature.fifths == 0,
       mode == "none" {
        return .empty
    }

    if keySignature.isDiatonic {
        guard let tonic = tonic(of: keySignature, mode: mode).flatMap(_abcPitchName),
              let standard = ABCKeySignature.Standard(tonic: tonic,
                                                      mode: mode.flatMap { abcModes[$0] } ?? .major)
        else { return cMajor }

        return .standard(standard)
    }

    let extraAccidentals = keySignature.accidentals.compactMap { pitchClass in
        ABCPitch.Octave(uintValue: 4).map {
            ABCPitch(letter: convertToABCPitchLetter(pitchClass.letter),
                     accidental: convertToABCPitchAccidental(pitchClass.accidental),
                     octave: $0)
        }
    }

    return ABCKeySignature.Standard(tonic: .c,
                                    mode: .explicit,
                                    extraAccidentals: extraAccidentals).map { .standard($0) } ?? cMajor
}

// A `K:` field's key signature and mode name: the accidentals
// `ABCKeySignature.accidentals` gives it (tonic and mode, then any extra or
// explicit accidentals), and its mode if it has no extra accidentals.
// `K:none` (or an empty `K:`) is no sharps or flats, with the mode "none". A
// key that only names a clef, or highland pipes, has the accidentals IvorABC
// gives it, which are what the walker spells notes by, and no mode. `nil`
// for one that needs a double sharp or flat.
internal func convertToKeySignature(_ abcKeySignature: ABCKeySignature) -> (keySignature: KeySignature, mode: String?)? {
    var accidentals: [PitchClass] = []

    for (letter, abcAccidental) in abcKeySignature.accidentals {
        let accidental: Pitch.Accidental

        switch abcAccidental {
        case .flat:
            accidental = .flat

        case .natural,
             .omitted:
            accidental = .natural

        case .sharp:
            accidental = .sharp

        case .doubleFlat,
             .doubleSharp:
            return nil
        }

        accidentals.append(PitchClass(letter: convertToPitchLetter(letter),
                                      accidental: accidental))
    }

    guard let keySignature = KeySignature(accidentals: accidentals)
    else { return nil }

    let mode: String? = switch abcKeySignature {
    case .empty:
        "none"

    case let .standard(standard) where standard.extraAccidentals.isEmpty:
        modeNames[standard.mode]

    default:
        nil
    }

    return (keySignature, mode)
}

// MARK: Private Constants

private let abcModes: [String: ABCKeySignature.Mode] = Dictionary(uniqueKeysWithValues: modeNames.map { ($1, $0) })

private let cMajor: ABCKeySignature = .standard(ABCKeySignature.Standard(tonic: .c, mode: .major).require())

private let modeNames: [ABCKeySignature.Mode: String] = [.aeolian: "aeolian",
                                                         .dorian: "dorian",
                                                         .ionian: "ionian",
                                                         .locrian: "locrian",
                                                         .lydian: "lydian",
                                                         .major: "major",
                                                         .minor: "minor",
                                                         .mixolydian: "mixolydian",
                                                         .phrygian: "phrygian"]

private let pitchNames: [PitchClass: ABCPitchName] = [.a: .a,
                                                      .aFlat: .aFlat,
                                                      .aSharp: .aSharp,
                                                      .b: .b,
                                                      .bFlat: .bFlat,
                                                      .bSharp: .bSharp,
                                                      .c: .c,
                                                      .cFlat: .cFlat,
                                                      .cSharp: .cSharp,
                                                      .d: .d,
                                                      .dFlat: .dFlat,
                                                      .dSharp: .dSharp,
                                                      .e: .e,
                                                      .eFlat: .eFlat,
                                                      .eSharp: .eSharp,
                                                      .f: .f,
                                                      .fFlat: .fFlat,
                                                      .fSharp: .fSharp,
                                                      .g: .g,
                                                      .gFlat: .gFlat,
                                                      .gSharp: .gSharp]

// MARK: Private Functions

private func _abcPitchName(_ pitchClass: PitchClass) -> ABCPitchName? {
    pitchNames[pitchClass]
}
