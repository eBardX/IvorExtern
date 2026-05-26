// © 2025–2026 John Gary Pusey (see LICENSE.md)

internal import IvorTuning

private import IvorMusicXML
private import XestiTools

// MARK: Internal Functions

internal func convertToStandardPitch(_ pitch: MusicXML.Pitch) throws -> Pitch {
    try Pitch(pitchClass: _convertToStandardPitchClass(pitch.letter,
                                                       pitch.accidental),
              octave: _convertToStandardPitchOctave(pitch.octave))
}

internal func determinePartName(_ part: MusicXML.PartPW,
                                _ scoreParts: [MusicXML.ScorePart]) -> String {
    scoreParts.first { $0.id == part.id }?.partName ?? ""
}

internal func determineWorkName(_ score: MusicXML.ScorePW) -> String {
    let movementNumber = score.movementNumber?.nilIfEmpty
    let movementTitle = score.movementTitle?.nilIfEmpty
    let workNumber = score.work?.workNumber?.nilIfEmpty
    let workTitle = score.work?.workTitle?.nilIfEmpty

    let combinedWorkTitle: String? = if let workTitle,
                                        let workNumber {
        workTitle + ", " + workNumber
    } else if let workTitle {
        workTitle
    } else if let workNumber {
        workNumber
    } else {
        nil
    }

    let combinedMovementTitle: String? = if let movementTitle,
                                            let movementNumber {
        movementTitle + ", " + movementNumber
    } else if let movementTitle {
        movementTitle
    } else if let movementNumber {
        movementNumber
    } else {
        nil
    }

    if let combinedWorkTitle,
       let combinedMovementTitle {
        return combinedWorkTitle + ": " + combinedMovementTitle
    }

    return combinedWorkTitle ?? combinedMovementTitle ?? ""
}

// MARK: Private Properties

private let accidentalMap: [MusicXML.Pitch.Accidental: Pitch.Accidental] = [.doubleFlat: .doubleFlat,
                                                                            .flat: .flat,
                                                                            .natural: .natural,
                                                                            .sharp: .sharp,
                                                                            .doubleSharp: .doubleSharp]

private let letterMap: [MusicXML.Pitch.Letter: Pitch.Letter] = [.a: .a,
                                                                .b: .b,
                                                                .c: .c,
                                                                .d: .d,
                                                                .e: .e,
                                                                .f: .f,
                                                                .g: .g]

// MARK: Private Functions

private func _convertToStandardPitchClass(_ mpLetter: MusicXML.Pitch.Letter,
                                          _ mpAccidental: MusicXML.Pitch.Accidental) throws -> PitchClass {
    guard let letter = letterMap[mpLetter]
    else { throw MusicXML.Error.unrecognizedPitchLetter(mpLetter) }

    guard let accidental = accidentalMap[mpAccidental]
    else { throw MusicXML.Error.unrecognizedPitchAccidental(mpAccidental) }

    return PitchClass(letter: letter,
                      accidental: accidental)
}

private func _convertToStandardPitchOctave(_ mpOctave: MusicXML.Pitch.Octave) throws -> Pitch.Octave {
    guard let octave = Pitch.Octave(intValue: mpOctave)
    else { throw MusicXML.Error.unrecognizedPitchOctave(mpOctave) }

    return octave
}
