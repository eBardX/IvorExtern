internal import IvorTiming
internal import IvorTuning

private import IvorGuido
private import XestiNumbers

// MARK: Internal Functions

internal func convertToBeatDuration(_ duration: Guido.Duration) throws -> BeatDuration {
    if let ms = duration.milliseconds {
        return BeatDuration(Number(numerator: ms,
                                   denominator: 1_000))
    }

    guard let numerator = duration.numerator,
          let denominator = duration.denominator,
          let dots = duration.dots
    else { throw Guido.Error.incompleteDuration(duration) }

    let base = BeatDuration(Number(numerator: numerator * 4,
                                   denominator: denominator))

    if dots == 0 {
        return base
    }

    guard let factor = dotsFactor[dots],
          let bdur = base.multiplied(by: factor)
    else { throw Guido.Error.incompleteDuration(duration) }

    return bdur
}

internal func convertToStandardPitch(_ pitch: Guido.Pitch) throws -> Pitch {
    try Pitch(pitchClass: _convertToStandardPitchClass(pitch.name,
                                                       pitch.accidental),
              octave: _convertToStandardPitchOctave(pitch.octave))
}

internal func determinePartName(_ voice: Guido.Voice) -> String {
    guard let tag = voice.findFirstTag(matching: ["\\instrument", "\\instr"]),
          let param = tag.parameters.first,
          param.hasNameOrNil("name")
    else { return "" }

    return param.stringValue ?? ""
}

internal func determineWorkName(_ score: Guido.Score) -> String {
    guard let voice = score.voices.first
    else { return "" }

    let titleTags = voice.findAllTags(matching: "\\title")
    let titles: [String] = titleTags.compactMap {
        guard let param = $0.parameters.first,
              param.hasNameOrNil("name")
        else { return nil }

        return param.stringValue
    }

    return titles.joined(separator: ": ")
}

// MARK: Private Properties

private let accidentalMap: [Guido.Pitch.Accidental: Pitch.Accidental] = [.doubleFlat: .doubleFlat,
                                                                         .flat: .flat,
                                                                         .natural: .natural,
                                                                         .sharp: .sharp,
                                                                         .impliedSharp: .sharp,
                                                                         .doubleSharp: .doubleSharp]

private let dotsFactor: [UInt: Number] = [1: Number(numerator: 3, denominator: 2),
                                          2: Number(numerator: 7, denominator: 4),
                                          3: Number(numerator: 15, denominator: 8)]

private let nameMap: [Guido.Pitch.Name: Pitch.Letter] = [.a: .a,
                                                         .ais: .a,
                                                         .b: .b,
                                                         .c: .c,
                                                         .cis: .c,
                                                         .d: .d,
                                                         .dis: .d,
                                                         .do: .c,
                                                         .e: .e,
                                                         .f: .f,
                                                         .fa: .f,
                                                         .fis: .f,
                                                         .g: .g,
                                                         .gis: .g,
                                                         .h: .b,
                                                         .la: .a,
                                                         .mi: .e,
                                                         .re: .d,
                                                         .si: .b,
                                                         .sol: .g,
                                                         .ti: .b]

// MARK: Private Functions

private func _convertToStandardPitchClass(_ gpName: Guido.Pitch.Name,
                                          _ gpAccidental: Guido.Pitch.Accidental) throws -> PitchClass {
    guard let letter = nameMap[gpName]
    else { throw Guido.Error.unrecognizedPitchName(gpName) }

    guard let accidental = accidentalMap[gpAccidental]
    else { throw Guido.Error.unrecognizedPitchAccidental(gpAccidental) }

    return PitchClass(letter: letter,
                      accidental: accidental)
}

private func _convertToStandardPitchOctave(_ gpOctave: Guido.Pitch.Octave) throws -> Pitch.Octave {
    guard let octave = Pitch.Octave(intValue: gpOctave + 3)
    else { throw Guido.Error.unrecognizedPitchOctave(gpOctave) }

    return octave
}
