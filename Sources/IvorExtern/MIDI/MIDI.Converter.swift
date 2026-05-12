internal import IvorModel

private import IvorMIDI
private import IvorTiming
private import IvorTuning
private import XestiNumbers
private import XestiTools

extension MIDI {

    // MARK: Internal Nested Types

    internal struct Converter {
    }
}

// MARK: -

extension MIDI.Converter {

    // MARK: Internal Instance Methods

    internal func convert(_ work: Work) throws -> MIDI.Sequence {
        throw MIDI.Error.convertFailure(nil)
    }

    internal func convert(_ sequence: MIDI.Sequence) throws -> Work {
        do {
            return try Self._convertToWork(sequence)
        } catch let error as any EnhancedError {
            throw MIDI.Error.convertFailure(error)
        }
    }

    // MARK: Private Type Methods

    private static func _convertToPart(_ channel: MIDI.Channel,
                                       _ beatMap: MIDI.BeatMap,
                                       _ track: MIDI.Track) throws -> Part<BeatTime, NoteNumber> {
        var context = Self.Context(beatMap: beatMap)

        for event in track.events {
            switch event {
            case let .meta(_, message):
                switch message {
                case let .sequenceTrackName(name):
                    if context.partName.isEmpty {
                        context.partName = "\(name.stringValue) (channel \(channel))"
                    }

                default:
                    break
                }

            case let .midi(eventTime, message):
                switch message {
                case let .noteOff(chan, note, _) where chan == channel:
                    context.handleNoteOff(eventTime, note)

                case let .noteOn(chan, note, vel) where chan == channel:
                    if vel.uintValue != 0 {
                        context.handleNoteOn(eventTime, note)
                    } else {
                        context.handleNoteOff(eventTime, note)
                    }

                default:
                    break
                }

            default:
                break
            }
        }

        return Part(name: context.partName,
                    noteTable: context.noteTable)
    }

    private static func _convertToTempoMap(_ beatMap: MIDI.BeatMap,
                                           _ track0: MIDI.Track) throws -> TempoMap {
        var tempoMap = TempoMap()
        var prevTempo: Tempo = .default

        for event in track0.events {
            switch event {
            case let .meta(eventTime, message):
                switch message {
                case let .tempo(tempo):
                    let (beatTime, factor) = beatMap[eventTime]
                    let rawTempo = round(factor * Number(numerator: 60_000_000,
                                                         denominator: tempo.uintValue)).exact
                    let currTempo = Tempo(rawTempo.uintValue)

                    tempoMap.insert(beatTime: beatTime,
                                    tempo: prevTempo)

                    tempoMap.insert(beatTime: beatTime,
                                    tempo: currTempo)

                    prevTempo = currTempo

                default:
                    break
                }

            default:
                break
            }
        }

        return tempoMap
    }

    private static func _convertToWork(_ sequence: MIDI.Sequence) throws -> Work {
        guard let track0 = sequence.tracks.first
        else { return Work(name: "",
                           content: .keyboardBeat([],
                                                  TempoMap())) }

        let beatMap = try convertToBeatMap(sequence.division, track0)

        var parts: [Part<BeatTime, NoteNumber>] = []

        for track in sequence.tracks {
            for rawChan: UInt in 1...16 {
                let part = try _convertToPart(MIDI.Channel(rawChan),
                                              beatMap,
                                              track)

                if !part.noteTable.isEmpty {
                    parts.append(part)
                }
            }
        }

        return try Work(name: determineWorkName(sequence),
                        content: .keyboardBeat(parts,
                                               _convertToTempoMap(beatMap, track0)))
    }
}

// MARK: - Sendable

extension MIDI.Converter: Sendable {
}
