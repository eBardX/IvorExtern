// © 2025–2026 John Gary Pusey (see LICENSE.md)

internal import Foundation
internal import IvorModel

private import IvorMIDI
private import IvorTiming
private import IvorTuning
private import XestiNumbers
private import XestiTools

extension MIDI {
    internal struct Importer {
    }
}

// MARK: - ImporterProtocol

extension MIDI.Importer: ImporterProtocol {

    // MARK: Internal Instance Properties

    internal var readableFileFormats: [FileFormat] {
        [.midi]
    }

    // MARK: Internal Instance Methods

    internal func read(from file: FileWrapper,
                       as fileFormat: FileFormat) throws -> [Work] {
        switch fileFormat {
        case .midi:
            guard let data = file.regularFileContents
            else { throw MIDI.Error.parseFailure(nil) }

            let sequence = try MIDI.Parser().parse(data)
            let work = try convert(sequence)

            return [work]

        default:
            throw MIDI.Error.unsupportedFileFormat(fileFormat.displayName)
        }
    }
}

// MARK: -

extension MIDI.Importer {

    // MARK: Internal Instance Methods

    internal func convert(_ sequence: MIDI.Sequence) throws -> Work {
        do {
            return try Self._convert(sequence: sequence)
        } catch let error as any EnhancedError {
            throw MIDI.Error.convertFailure(error)
        }
    }

    // MARK: Private Type Methods

    private static func _convert(sequence: MIDI.Sequence) throws -> Work {
        guard let track0 = sequence.tracks.first
        else { return Work(name: "",
                           content: .keyboardBeat([],
                                                  TempoMap())) }

        let beatMap = try _makeBeatMap(division: sequence.division,
                                       track0: track0)

        var parts: [Part<BeatTime, NoteNumber>] = []

        for track in sequence.tracks {
            for rawChan: UInt in 1...16 {
                let part = try _convert(track: track,
                                        channel: MIDI.Channel(rawChan),
                                        beatMap: beatMap)

                if !part.noteTable.isEmpty {
                    parts.append(part)
                }
            }
        }

        return try Work(name: determineWorkName(sequence),
                        content: .keyboardBeat(parts,
                                               _convert(track0: track0,
                                                        beatMap: beatMap)))
    }

    private static func _convert(track: MIDI.Track,
                                 channel: MIDI.Channel,
                                 beatMap: MIDI.BeatMap) throws -> Part<BeatTime, NoteNumber> {
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

                case let .controlChange(chan, controller, value) where chan == channel:
                    switch controller {
                    case .panMSB:
                        context.handlePan(eventTime, value)

                    default:
                        break
                    }

                case let .noteOn(chan, note, velocity) where chan == channel:
                    if velocity.uintValue != 0 {
                        context.handleNoteOn(eventTime, note, velocity)
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
                    noteTable: context.noteTable,
                    dynamicMap: context.dynamicMap,
                    panMap: context.panMap)
    }

    private static func _convert(track0: MIDI.Track,
                                 beatMap: MIDI.BeatMap) throws -> TempoMap {
        var tempoMap = TempoMap()
        var prevTempo: Tempo = .default

        for event in track0.events {
            switch event {
            case let .meta(eventTime, message):
                switch message {
                case let .tempo(tempo):
                    let (beatTime, factor) = beatMap[eventTime]
                    let currTempo = convertToTempo(tempo, factor)

                    if beatTime != .zero {
                        tempoMap.insert(beatTime: beatTime,
                                        tempo: prevTempo)
                    }

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

    private static func _makeBeatMap(division: MIDI.Division,
                                     track0: MIDI.Track) throws -> MIDI.BeatMap {
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
}

// MARK: - Sendable

extension MIDI.Importer: Sendable {
}
