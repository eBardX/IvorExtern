private import IvorMIDI

// MARK: Internal Functions

internal func convertToBeatMap(_ division: MIDI.Division,
                               _ track0: MIDI.Track) throws -> MIDI.BeatMap {
    var beatMap = try MIDI.BeatMap(division: division)

    for event in track0.events {
        switch event {
        case let .meta(eventTime, message):
            switch message {
            case let .timeSignature(tsig):
                try beatMap.append(eventTime: eventTime,
                                   clockRate: tsig.clockRate)

            default:
                break
            }

        default:
            break
        }
    }

    return beatMap
}

internal func determineWorkName(_ sequence: MIDI.Sequence) -> String {
    guard let track0 = sequence.tracks.first
    else { return "" }

    for event in track0.events {
        switch event {
        case let .meta(_, message):
            switch message {
            case let .sequenceTrackName(name):
                return name.stringValue

            default:
                break
            }

        default:
            break
        }
    }

    return ""
}
