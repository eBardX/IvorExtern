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

// MARK: -

extension MIDI.Importer {

    // MARK: Internal Instance Methods

    internal func convert(_ sequence: MIDI.Sequence) throws(MIDI.Error) -> Work {
        do {
            return try Self._convert(sequence)
        } catch let error as any EnhancedError {
            throw MIDI.Error.convertFailure(error)
        } catch {
            throw MIDI.Error.convertFailure(nil)
        }
    }

    // MARK: Private Type Methods

    private static func _convert(_ sequence: MIDI.Sequence) throws -> Work {
        let (normalized, _) = MIDI.Normalizer().normalize(sequence)
        let (validated, issues) = try MIDI.Validator().validate(normalized)

        guard issues.isEmpty
        else { throw MIDI.Error.validationFailure(issues) }

        let timeline = _timeline(validated.tracks)
        let beatMap = try _makeBeatMap(validated.division,
                                       timeline)
        let voices = try _makeVoices(validated.tracks)
        let parts = _convert(voices,
                             beatMap)
        let tempoMap = _convert(timeline,
                                beatMap)

        return Work(name: determineWorkName(validated),
                    content: .keyboardBeat(parts,
                                           tempoMap))
    }

    private static func _convert(_ timeline: [MIDI.TimelineEvent],
                                 _ beatMap: MIDI.BeatMap) -> TempoMap {
        var tempoMap = TempoMap()
        var prevTempo: Tempo = .default

        for event in timeline {
            guard case let .meta(eventTime, .tempo(tempo)) = event
            else { continue }

            let (beatTime, factor) = beatMap[eventTime]
            let currTempo = convertToTempo(tempo, factor)

            if beatTime != .zero {
                tempoMap.insert(beatTime: beatTime,
                                tempo: prevTempo)
            }

            tempoMap.insert(beatTime: beatTime,
                            tempo: currTempo)

            prevTempo = currTempo
        }

        return tempoMap
    }

    private static func _convert(_ voice: MIDI.Voice,
                                 _ beatMap: MIDI.BeatMap) -> Part<BeatTime, NoteNumber> {
        var context = Self.Context(beatMap: beatMap)

        for note in voice.notes {
            context.handleNote(note)
        }

        for case let .midi(eventTime, .controlChange(_, _, value)) in voice.panEvents {
            context.handlePan(eventTime, value)
        }

        return Part(name: voice.name,
                    noteTable: context.noteTable,
                    dynamicMap: context.dynamicMap,
                    instrumentMap: _makeInstrumentMap(voice.programChangeEvents, beatMap),
                    panMap: context.panMap)
    }

    private static func _convert(_ voices: [MIDI.Voice],
                                 _ beatMap: MIDI.BeatMap) -> [Part<BeatTime, NoteNumber>] {
        voices.map { _convert($0, beatMap) }
    }

    private static func _makeBeatMap(_ division: MIDI.Division,
                                     _ timeline: [MIDI.TimelineEvent]) throws(MIDI.Error) -> MIDI.BeatMap {
        var beatMap = try MIDI.BeatMap(division: division)

        for event in timeline {
            guard case let .meta(eventTime, .timeSignature(tsig)) = event
            else { continue }

            try beatMap.append(eventTime: eventTime,
                               clockRate: tsig.clockRate)
        }

        return beatMap
    }

    private static func _makeInstrumentMap(_ events: [SMFEvent],
                                           _ beatMap: MIDI.BeatMap) -> InstrumentMap<BeatTime> {
        var instrumentMap = InstrumentMap<BeatTime>()

        for case let .midi(eventTime, .programChange(_, program)) in events {
            let (beatTime, _) = beatMap[eventTime]

            instrumentMap.insert(time: beatTime,
                                 instrument: convertToInstrument(program))
        }

        return instrumentMap
    }

    private static func _makeVoice(channel: MIDI.Channel,
                                   name: String,
                                   events: [SMFEvent]) throws(MIDI.Error) -> MIDI.Voice {
        var pairer = NotePairer(channel: channel)

        for event in events.sorted(by: { $0.eventTime < $1.eventTime }) {
            try pairer.ingest(event)
        }

        return try pairer.makeVoice(name: name)
    }

    // A track's own name is used as-is when it carries a single channel —
    // the common case, and the one-part-per-track convention
    // `MIDI.Exporter` itself writes — and disambiguated with the channel
    // number only when a track packs more than one channel into itself,
    // mirroring `MusicXML.Importer`'s own `_makePartName`. An unnamed
    // track falls back to "Channel N" alone, the exact form
    // `MIDI.Exporter._assignChannels` reads back to recover the channel on
    // export.
    private static func _makeVoiceName(trackName: String?,
                                       channel: MIDI.Channel,
                                       isMultiChannel: Bool) -> String {
        guard let trackName, !trackName.isEmpty
        else { return "Channel \(channel.uintValue)" }

        guard isMultiChannel
        else { return trackName }

        return "\(trackName), Channel \(channel.uintValue)"
    }

    // One `MIDI.Voice` per (track, channel) pair actually used — not just
    // per channel — so a Standard MIDI File that puts each part on its own
    // track, all sharing one channel (the common single-instrument
    // convention this importer's own `MIDI.Exporter` writes), comes back
    // as one part per track instead of collapsing every same-channel track
    // into one. A track using more than one channel still splits per
    // channel within itself, same as before; a track with no channel
    // events at all (a tempo/name-only track) contributes no voice.
    private static func _makeVoices(_ tracks: [MIDI.Track]) throws(MIDI.Error) -> [MIDI.Voice] {
        var voices: [MIDI.Voice] = []

        for track in tracks {
            var channelEvents: [MIDI.Channel: [SMFEvent]] = [:]

            for event in track.events {
                guard case let .midi(_, message) = event
                else { continue }

                channelEvents[message.channel, default: []].append(event)
            }

            guard !channelEvents.isEmpty
            else { continue }

            let trackName = determineTrackName(track)
            let isMultiChannel = channelEvents.count > 1

            for channel in channelEvents.keys.sorted() {
                try voices.append(_makeVoice(channel: channel,
                                             name: _makeVoiceName(trackName: trackName,
                                                                  channel: channel,
                                                                  isMultiChannel: isMultiChannel),
                                             events: channelEvents[channel] ?? []))
            }
        }

        return voices
    }

    // The tick-ordered timeline of every track's meta events (tempo, time
    // signature, and so on), gathered across all tracks since a Standard
    // MIDI File is free to carry one anywhere, though convention puts them
    // on track 0. End-of-track meta events and system exclusive events are
    // both dropped — the former is a track-boundary wire artifact, the
    // latter is never read.
    private static func _timeline(_ tracks: [MIDI.Track]) -> [MIDI.TimelineEvent] {
        var timeline: [MIDI.TimelineEvent] = []

        for track in tracks {
            for event in track.events {
                switch event {
                case .meta(_, .endOfTrack),
                     .midi,
                     .sysEx:
                    continue

                case .meta:
                    timeline.append(event)
                }
            }
        }

        timeline.sort { $0.eventTime < $1.eventTime }

        return timeline
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
                       as fileFormat: FileFormat) throws(MIDI.Error) -> [Work] {
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

// MARK: - Sendable

extension MIDI.Importer: Sendable {
}
