// © 2025–2026 John Gary Pusey (see LICENSE.md)

internal import IvorABC
internal import IvorTiming
internal import IvorTuning

private import XestiNumbers

// MARK: Internal Functions

internal func convertToBeatDuration(_ duration: ABC.Duration) throws -> BeatDuration {
    BeatDuration(Number(numerator: duration.numerator,
                        denominator: duration.denominator))
}

internal func convertToStandardPitch(_ pitch: ABC.Pitch) throws -> Pitch {
    try Pitch(pitchClass: _convertToStandardPitchClass(pitch.letter,
                                                       pitch.accidental),
              octave: _convertToStandardPitchOctave(pitch.octave))
}

internal func determineVoices(_ tune: ABC.Tune) -> [ABC.Voice] {
    var voices: [ABC.Voice] = []

    for entry in tune.entries {
        switch entry {
        case let .field(field):
            voices += _determineVoices(field)

        case let .symbols(symbols):
            voices += _determineVoices(symbols)

        default:
            break
        }
    }

    return _uniquify(voices)
}

internal func determineWorkName(_ tune: ABC.Tune) -> String {
    for entry in tune.entries {
        switch entry {
        case let .field(field):
            if let name = _determineWorkName(field) {
                return name
            }

        default:
            break
        }
    }

    return ""
}

internal func filterEntries(_ voice: ABC.Voice,
                            _ tune: ABC.Tune) throws -> [ABC.Entry] {
    var filteredEntries: [ABC.Entry] = []
    var currentVoice = ABC.Voice(id: "",
                                 properties: [:])

    for entry in tune.entries {
        switch entry {
        case let .field(field):
            if case let .voice(voice) = field {
                currentVoice = voice
            }

            fallthrough // swiftlint:disable:this fallthrough

        case .directive:
            if currentVoice.id == voice.id {
                filteredEntries.append(entry)
            }

        case let .symbols(symbols):
            let filteredSymbols = _filterSymbols(voice, symbols, &currentVoice)

            if currentVoice.id == voice.id {
                filteredEntries.append(.symbols(filteredSymbols))
            }
        }
    }

    return filteredEntries
}

// MARK: Private Properties

private let accidentalMap: [ABC.Pitch.Accidental: Pitch.Accidental] = [.doubleFlat: .doubleFlat,
                                                                       .flat: .flat,
                                                                       .natural: .natural,
                                                                       .sharp: .sharp,
                                                                       .doubleSharp: .doubleSharp]

private let letterMap: [ABC.Pitch.Letter: Pitch.Letter] = [.a: .a,
                                                           .b: .b,
                                                           .c: .c,
                                                           .d: .d,
                                                           .e: .e,
                                                           .f: .f,
                                                           .g: .g]

// MARK: Private Functions

private func _convertToStandardPitchClass(_ apLetter: ABC.Pitch.Letter,
                                          _ apaccidental: ABC.Pitch.Accidental) throws -> PitchClass {
    guard let letter = letterMap[apLetter]
    else { throw ABC.Error.unrecognizedPitchLetter(apLetter) }

    guard let accidental = accidentalMap[apaccidental]
    else { throw ABC.Error.unrecognizedPitchAccidental(apaccidental) }

    return PitchClass(letter: letter,
                      accidental: accidental)
}

private func _convertToStandardPitchOctave(_ apOctave: ABC.Pitch.Octave) throws -> Pitch.Octave {
    guard let octave = Pitch.Octave(intValue: apOctave)
    else { throw ABC.Error.unrecognizedPitchOctave(apOctave) }

    return octave
}

private func _determineVoices(_ field: ABC.Field) -> [ABC.Voice] {
    switch field {
    case let .voice(voice):
        [voice]

    default:
        []
    }
}

private func _determineVoices(_ symbols: [ABC.Symbol]) -> [ABC.Voice] {
    var voices: [ABC.Voice] = []

    for symbol in symbols {
        switch symbol {
        case let .inlineField(field):
            voices += _determineVoices(field)

        default:
            break
        }
    }

    return voices
}

private func _determineWorkName(_ field: ABC.Field) -> String? {
    switch field {
    case let .title(title):
        title

    default:
        nil
    }
}

private func _filterSymbols(_ voice: ABC.Voice,
                            _ symbols: [ABC.Symbol],
                            _ currentVoice: inout ABC.Voice) -> [ABC.Symbol] {
    var outSymbols: [ABC.Symbol] = []

    for symbol in symbols {
        switch symbol {
        case let .inlineField(field):
            if case let .voice(voice) = field {
                currentVoice = voice
            }

            fallthrough // swiftlint:disable:this fallthrough

        default:
            if currentVoice.id == voice.id {
                outSymbols.append(symbol)
            }
        }
    }

    return outSymbols
}

private func _uniquify(_ voices: [ABC.Voice]) -> [ABC.Voice] {
    var outVoices: [ABC.Voice] = []

    for voice in voices where !outVoices.contains(where: { $0.id == voice.id }) {
        outVoices.append(voice)
    }

    return outVoices
}
