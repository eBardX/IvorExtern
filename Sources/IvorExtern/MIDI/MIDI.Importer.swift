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
                            tempo: currTempo,
                            extras: Extras(elements: [Extra(name: Extra.midiTempo.name,
                                                            values: [.int(Int(tempo.uintValue))])]))

            prevTempo = currTempo
        }

        return tempoMap
    }

    private static func _convert(_ voice: MIDI.Voice,
                                 _ instrumentNameEvents: [SMFEvent],
                                 _ beatMap: MIDI.BeatMap) -> Part<BeatTime, NoteNumber> {
        var context = Self.Context(beatMap: beatMap)

        for note in voice.notes {
            context.handleNote(note)
        }

        var panLSB: UInt?

        for case let .midi(eventTime, message) in voice.panEvents.sorted(by: { $0.eventTime < $1.eventTime }) {
            switch message {
            case let .controlChange(_, .panLSB, value):
                panLSB = value.uintValue

            case let .controlChange(_, .panMSB, value):
                context.handlePan(eventTime, value, panLSB)

            default:
                continue
            }
        }

        var exprMSB: UInt?
        var exprLSB: UInt?

        for case let .midi(eventTime, message) in voice.expressionEvents.sorted(by: { $0.eventTime < $1.eventTime }) {
            switch message {
            case let .controlChange(_, .expressionControllerMSB, value):
                exprMSB = value.uintValue

            case let .controlChange(_, .expressionControllerLSB, value):
                exprLSB = value.uintValue

            default:
                continue
            }

            if let exprMSB {
                context.handleExpression(eventTime, Int((exprMSB << 7) | (exprLSB ?? 0)))
            }
        }

        let instrumentMap = _makeInstrumentMap(voice.programChangeEvents,
                                               voice.bankSelectEvents,
                                               voice.volumeEvents,
                                               instrumentNameEvents,
                                               channel: voice.channel,
                                               beatMap)

        return Part(name: voice.name.nilIfEmpty ?? _makeUnnamedPartName(instrumentMap,
                                                                        hasInstrumentName: !instrumentNameEvents.isEmpty,
                                                                        channel: voice.channel),
                    noteTable: context.noteTable,
                    dynamicMap: context.dynamicMap,
                    instrumentMap: instrumentMap,
                    panMap: context.panMap)
    }

    private static func _convert(_ voices: [(voice: MIDI.Voice, instrumentNameEvents: [SMFEvent])],
                                 _ beatMap: MIDI.BeatMap) -> [Part<BeatTime, NoteNumber>] {
        voices.map { _convert($0.voice, $0.instrumentNameEvents, beatMap) }
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

    // Program Change events carry every `InstrumentMap` entry's own time and
    // (absent an override) instrument; Bank Select (CC 0 MSB / CC 32 LSB)
    // and Channel Volume events are stateful, not tied to any one entry, so
    // they're merged in tick order alongside the program changes and the
    // most recently seen MSB/LSB pair (if any) is combined into a 14-bit
    // `midiBank` extra at each entry — see `Extra+InstrumentMap.swift`.
    // Instrument Name (`FF 04`) meta events are merged the same stateful
    // way: the most recently seen name, if any, wins over the generic
    // General MIDI name `convertToInstrument(program)` would otherwise
    // derive — the same "explicit name beats a program-derived guess"
    // priority `Guido`'s and `MusicXML`'s own `convertToInstrument`
    // functions give their own named-vs-program instrument sources. Bank
    // Select and Instrument Name are both placed ahead of Program Change in
    // the merge so a coincident event (same tick) resolves in MIDI
    // convention order.
    private static func _makeInstrumentMap(_ programChangeEvents: [SMFEvent],
                                           _ bankSelectEvents: [SMFEvent],
                                           _ volumeEvents: [SMFEvent],
                                           _ instrumentNameEvents: [SMFEvent],
                                           channel: MIDI.Channel,
                                           _ beatMap: MIDI.BeatMap) -> InstrumentMap<BeatTime> {
        var instrumentMap = InstrumentMap<BeatTime>()
        var bankMSB: UInt?
        var bankLSB: UInt?
        var volume: UInt?
        var instrumentName: String?

        let events = (instrumentNameEvents + bankSelectEvents + volumeEvents + programChangeEvents)
            .sorted { $0.eventTime < $1.eventTime }

        for event in events {
            switch event {
            case let .meta(_, .instrumentName(text)):
                instrumentName = text.stringValue.nilIfEmpty

            case let .midi(_, .controlChange(_, .bankSelectMSB, value)):
                bankMSB = value.uintValue

            case let .midi(_, .controlChange(_, .bankSelectLSB, value)):
                bankLSB = value.uintValue

            case let .midi(_, .controlChange(_, .channelVolumeMSB, value)):
                volume = value.uintValue

            case let .midi(eventTime, .programChange(_, program)):
                let (beatTime, _) = beatMap[eventTime]
                var elements = [Extra(name: Extra.midiChannel.name, values: [.int(Int(channel.uintValue))]),
                                Extra(name: Extra.midiProgram.name, values: [.int(Int(program.uintValue) + 1)])]

                if let volume {
                    elements.append(Extra(name: Extra.midiVolume.name,
                                          values: [.double(Double(volume) / 127.0 * 100.0)]))
                }

                if let bankMSB, let bankLSB {
                    elements.append(Extra(name: Extra.midiBank.name,
                                          values: [.int(Int((bankMSB << 7) | bankLSB) + 1)]))
                }

                let instrument = instrumentName.flatMap { Instrument(stringValue: $0) } ?? convertToInstrument(program)

                instrumentMap.insert(time: beatTime,
                                     instrument: instrument,
                                     extras: Extras(elements: elements))

            default:
                break
            }
        }

        return instrumentMap
    }

    // A voice from an unnamed track is named after its first instrument —
    // an Instrument Name meta event's text, else the General MIDI program
    // name, or "Percussion" on channel 10, where the program number doesn't
    // pick a melodic instrument — but only when it has one: that entry's
    // `midiChannel` extra is what `MIDI.Exporter` reads first to recover
    // the channel on export. With no Program Change there's no such extra,
    // so the voice falls back to "Channel N" alone, the exact form
    // `MIDI.Exporter._parseChannelName` reads back instead.
    private static func _makeUnnamedPartName(_ instrumentMap: InstrumentMap<BeatTime>,
                                             hasInstrumentName: Bool,
                                             channel: MIDI.Channel) -> String {
        var firstInstrument: Instrument?

        instrumentMap.forEach { _, _, instrument, _ in
            if firstInstrument == nil {
                firstInstrument = instrument
            }
        }

        guard let firstInstrument
        else { return "Channel \(channel.uintValue)" }

        guard hasInstrumentName || channel.uintValue != 10
        else { return "Percussion" }

        return firstInstrument.stringValue
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
    // track's voices stay unnamed here, left for `_makeUnnamedPartName`
    // once their instrument maps are known.
    private static func _makeVoiceName(trackName: String?,
                                       channel: MIDI.Channel,
                                       isMultiChannel: Bool) -> String {
        guard let trackName, !trackName.isEmpty
        else { return "" }

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
    // Instrument Name meta events aren't channel-scoped — unlike Program
    // Change, MIDI has nowhere to attach one to a single channel within a
    // multi-channel track — so every voice split from a track shares that
    // track's own set of them, the same way a multi-channel track's voices
    // already share its one track name. A lone track's name isn't used for
    // its voices at all: `determineWorkName` has already taken it as the
    // work's title — the Format 0 convention — and repeating it on every
    // part ("My Song, Channel 1") would only mislabel them.
    private static func _makeVoices(_ tracks: [MIDI.Track]) throws(MIDI.Error) -> [(voice: MIDI.Voice, instrumentNameEvents: [SMFEvent])] {
        var voices: [(voice: MIDI.Voice, instrumentNameEvents: [SMFEvent])] = []

        for track in tracks {
            var channelEvents: [MIDI.Channel: [SMFEvent]] = [:]

            for event in track.events {
                guard case let .midi(_, message) = event
                else { continue }

                channelEvents[message.channel, default: []].append(event)
            }

            guard !channelEvents.isEmpty
            else { continue }

            let trackName = tracks.count > 1 ? determineTrackName(track) : nil
            let isMultiChannel = channelEvents.count > 1
            let instrumentNameEvents = track.events.filter {
                if case .meta(_, .instrumentName) = $0 { true } else { false }
            }

            for channel in channelEvents.keys.sorted() {
                let voice = try _makeVoice(channel: channel,
                                           name: _makeVoiceName(trackName: trackName,
                                                                channel: channel,
                                                                isMultiChannel: isMultiChannel),
                                           events: channelEvents[channel] ?? [])

                voices.append((voice, instrumentNameEvents))
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
