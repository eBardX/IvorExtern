// © 2026 John Gary Pusey (see LICENSE.md)

internal import IvorABC
internal import IvorTuning

private import XestiTools

// MARK: Internal Functions

// The `K:` field for a key, or `K:C` for none. A diatonic key is written as
// its tonic and mode (`K:Bm`, `K:Edor`), or as its major key when it has no
// mode (`K:G`), since ABC always names a tonic. An atonal key is `K:none`. A
// custom key is written as `K:C exp` with its accidentals, in canonical
// order (`K:C exp _b ^f`), so its meaning doesn't depend on any key's own.
internal func convertToABCKeySignature(_ key: Key?) -> ABCKeySignature {
    switch key {
    case nil:
        return cMajor

    case .atonal:
        return .empty

    case let .custom(signature):
        let extraAccidentals = signature.accidentals.compactMap { pitchClass in
            ABCPitch.Octave(uintValue: 4).map {
                ABCPitch(letter: convertToABCPitchLetter(pitchClass.letter),
                         accidental: convertToABCPitchAccidental(pitchClass.accidental),
                         octave: $0)
            }
        }

        return ABCKeySignature.Standard(tonic: .c,
                                        mode: .explicit,
                                        extraAccidentals: extraAccidentals).map { .standard($0) } ?? cMajor

    case let .diatonic(diatonic):
        guard let key,
              let tonic = writtenTonic(of: key).flatMap(_abcPitchName),
              let standard = ABCKeySignature.Standard(tonic: tonic,
                                                      mode: abcModes[diatonic.mode ?? .major] ?? .major)
        else { return cMajor }

        return .standard(standard)
    }
}

// A `K:` field's key. `K:none` (or an empty `K:`) is atonal. A tonic and mode
// with no extra accidentals is a diatonic key in that mode (no mode written
// means major, as ABC defines it). Anything else is the key the accidentals
// `ABCKeySignature.accidentals` gives it make (tonic and mode, then any extra
// or explicit accidentals), with no mode: a key that only names a clef, or
// highland pipes, has the accidentals IvorABC gives it, which are what the
// walker spells notes by. `nil` for one that needs a double sharp or flat.
internal func convertToKey(_ abcKeySignature: ABCKeySignature) -> Key? {
    if case .empty = abcKeySignature {
        return .atonal
    }

    var accidentals: [PitchClass] = []

    for (letter, abcAccidental) in abcKeySignature.accidentals {
        let accidental: Pitch.Accidental

        switch abcAccidental {
        case .doubleFlat,
             .doubleSharp:
            return nil

        case .flat:
            accidental = .flat

        case .natural,
             .omitted:
            accidental = .natural

        case .sharp:
            accidental = .sharp
        }

        accidentals.append(PitchClass(letter: convertToPitchLetter(letter),
                                      accidental: accidental))
    }

    guard let key = Key(accidentals: accidentals)
    else { return nil }

    guard case let .standard(standard) = abcKeySignature,
          standard.extraAccidentals.isEmpty,
          let mode = keyModes[standard.mode],
          let fifths = key.fifths
    else { return key }

    return Key.diatonic(fifths: fifths,
                        mode: mode) ?? key
}

// MARK: Private Constants

private let abcModes: [Key.Mode: ABCKeySignature.Mode] = [.dorian: .dorian,
                                                          .locrian: .locrian,
                                                          .lydian: .lydian,
                                                          .major: .major,
                                                          .minor: .minor,
                                                          .mixolydian: .mixolydian,
                                                          .phrygian: .phrygian]

private let cMajor: ABCKeySignature = .standard(ABCKeySignature.Standard(tonic: .c, mode: .major).require())

private let keyModes: [ABCKeySignature.Mode: Key.Mode] = [.aeolian: .minor,
                                                          .dorian: .dorian,
                                                          .ionian: .major,
                                                          .locrian: .locrian,
                                                          .lydian: .lydian,
                                                          .major: .major,
                                                          .minor: .minor,
                                                          .mixolydian: .mixolydian,
                                                          .phrygian: .phrygian]

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
