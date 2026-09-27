// © 2025–2026 John Gary Pusey (see LICENSE.md)

internal import Foundation
internal import IvorModel

private import IvorMIDI
private import IvorSMF
private import IvorSMPTE
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

    // A wall-time work has no tempo map to carry the file's SMPTE timing
    // (see `_makeStartElements`), so it's recorded on each part's
    // instrument map entry at time zero instead, where `MIDI.Exporter`
    // looks for it. When a part has no such entry, one holding the default
    // instrument is inserted for it, carrying the part's `midiChannel`
    // extra too, since the exporter reads the channel from a part's first
    // entry.
    private static func _addStartElements(_ startElements: [Extra],
                                          channel: MIDI.Channel,
                                          to instrumentMap: inout InstrumentMap<some TimeProtocol>) {
        guard !startElements.isEmpty
        else { return }

        var startEntry: (entryID: EntryID, instrument: Instrument, extras: Extras?)?

        instrumentMap.forEach { entryID, time, instrument, extras in
            if startEntry == nil, time == .zero {
                startEntry = (entryID, instrument, extras)
            }
        }

        if let startEntry {
            instrumentMap.update(entryID: startEntry.entryID,
                                 instrument: startEntry.instrument,
                                 extras: Extras(elements: (startEntry.extras?.elements ?? []) + startElements))
        } else {
            instrumentMap.insert(time: .zero,
                                 instrument: instrumentMap.defaultInstrument,
                                 extras: Extras(elements: [Extra(name: Extra.midiChannel.name,
                                                                 values: [.int(Int(channel.uintValue))])] + startElements))
        }
    }

    private static func _convert(_ sequence: MIDI.Sequence) throws -> Work {
        let (normalized, _) = MIDI.Normalizer().normalize(sequence)
        let (validated, issues) = try MIDI.Validator().validate(normalized)

        guard issues.isEmpty
        else { throw MIDI.Error.validationFailure(issues) }

        let timeline = _timeline(validated.tracks)
        let voices = try _makeVoices(validated.tracks)

        return try Work(name: determineWorkName(validated),
                        content: _convert(voices,
                                          timeline,
                                          validated.division))
    }

    // A file with a timecode division and no tempo events has no beats to
    // speak of — its ticks measure wall time alone — so it's imported as
    // wall time, with its SMPTE timing recorded on each part instead of on
    // a tempo map (see `_addStartElements`). Every other file is imported
    // as beat time.
    private static func _convert(_ voices: [(voice: MIDI.Voice, instrumentNameEvents: [SMFEvent])],
                                 _ timeline: [MIDI.Event],
                                 _ division: MIDI.Division) throws(MIDI.Error) -> Work.Content {
        if case let .timeCode(timeCode) = division,
           !timeline.contains(where: { if case .meta(_, .tempo) = $0 { true } else { false } }) {
            return .keyboardWall(_convert(voices,
                                          MIDI.WallMap(timeCode: timeCode),
                                          startElements: _makeStartElements(timeline,
                                                                            division)))
        }

        let beatMap = try _makeBeatMap(division,
                                       timeline)

        return .keyboardBeat(_convert(voices,
                                      beatMap,
                                      startElements: []),
                             _convert(timeline,
                                      division,
                                      beatMap))
    }

    // The SMPTE timing of the file — its timecode division, if any, and its
    // SMPTE Offset (`FF 54`) meta event, if any — is recorded as extras on
    // the tempo map entry at beat zero, so that `MIDI.Exporter` can write it
    // back and an `SMPTETimeConverter` can label the work's wall times. When
    // there's no tempo event at tick zero to carry them, an entry at beat
    // zero holding the default tempo is inserted for them.
    private static func _convert(_ timeline: [MIDI.Event],
                                 _ division: MIDI.Division,
                                 _ beatMap: MIDI.BeatMap) -> TempoMap {
        var tempoMap = TempoMap()
        var prevTempo: Tempo = .default
        var startElements = _makeStartElements(timeline,
                                               division)

        for event in timeline {
            guard case let .meta(eventTime, .tempo(tempo)) = event
            else { continue }

            let (beatTime, factor) = beatMap[eventTime]
            let currTempo = convertToTempo(tempo, factor)

            if beatTime != .zero {
                if !startElements.isEmpty {
                    tempoMap.insert(beatTime: .zero,
                                    tempo: prevTempo,
                                    extras: Extras(elements: startElements))

                    startElements = []
                }

                tempoMap.insert(beatTime: beatTime,
                                tempo: prevTempo)
            }

            tempoMap.insert(beatTime: beatTime,
                            tempo: currTempo,
                            extras: Extras(elements: [Extra(name: Extra.midiTempo.name,
                                                            values: [.int(Int(tempo.uintValue))])] + startElements))

            startElements = []
            prevTempo = currTempo
        }

        if !startElements.isEmpty {
            tempoMap.insert(beatTime: .zero,
                            tempo: prevTempo,
                            extras: Extras(elements: startElements))
        }

        return tempoMap
    }

    private static func _convert<TimeMap: MIDI.ImportTimeMap>(_ voice: MIDI.Voice,
                                                              _ instrumentNameEvents: [SMFEvent],
                                                              _ timeMap: TimeMap,
                                                              startElements: [Extra]) -> Part<TimeMap.TimeType, NoteNumber> {
        var context = Self.Context(timeMap: timeMap)

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

        var instrumentMap = _makeInstrumentMap(voice.programChangeEvents,
                                               voice.bankSelectEvents,
                                               voice.volumeEvents,
                                               instrumentNameEvents,
                                               channel: voice.channel,
                                               timeMap)
        let name = voice.name.nilIfEmpty ?? _makeUnnamedPartName(instrumentMap,
                                                                 hasInstrumentName: !instrumentNameEvents.isEmpty,
                                                                 channel: voice.channel)

        _addStartElements(startElements,
                          channel: voice.channel,
                          to: &instrumentMap)

        return Part(name: name,
                    noteTable: context.noteTable,
                    dynamicMap: context.dynamicMap,
                    instrumentMap: instrumentMap,
                    panMap: context.panMap)
    }

    private static func _convert<TimeMap: MIDI.ImportTimeMap>(_ voices: [(voice: MIDI.Voice, instrumentNameEvents: [SMFEvent])],
                                                              _ timeMap: TimeMap,
                                                              startElements: [Extra]) -> [Part<TimeMap.TimeType, NoteNumber>] {
        voices.map { _convert($0.voice, $0.instrumentNameEvents, timeMap, startElements: startElements) }
    }

    private static func _makeBeatMap(_ division: MIDI.Division,
                                     _ timeline: [MIDI.Event]) throws(MIDI.Error) -> MIDI.BeatMap {
        var beatMap = try MIDI.BeatMap(division: division)

        for event in timeline {
            switch event {
            case let .meta(eventTime, .tempo(tempo)):
                try beatMap.append(eventTime: eventTime,
                                   tempo: tempo.uintValue)

            case let .meta(eventTime, .timeSignature(tsig)):
                try beatMap.append(eventTime: eventTime,
                                   clockRate: tsig.clockRate)

            default:
                continue
            }
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
    private static func _makeInstrumentMap<TimeMap: MIDI.ImportTimeMap>(_ programChangeEvents: [SMFEvent],
                                                                        _ bankSelectEvents: [SMFEvent],
                                                                        _ volumeEvents: [SMFEvent],
                                                                        _ instrumentNameEvents: [SMFEvent],
                                                                        channel: MIDI.Channel,
                                                                        _ timeMap: TimeMap) -> InstrumentMap<TimeMap.TimeType> {
        var instrumentMap = InstrumentMap<TimeMap.TimeType>()
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
                let time = timeMap.time(at: eventTime)
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

                instrumentMap.insert(time: time,
                                     instrument: instrument,
                                     extras: Extras(elements: elements))

            default:
                break
            }
        }

        return instrumentMap
    }

    // Only the first SMPTE Offset at tick zero counts: the SMF specification
    // requires the event to precede any nonzero delta time, and in a
    // format 1 file the one on the first track (the tempo map) applies to
    // them all.
    private static func _makeStartElements(_ timeline: [MIDI.Event],
                                           _ division: MIDI.Division) -> [Extra] {
        var elements: [Extra] = []

        if case let .timeCode(timeCode) = division {
            elements.append(Extra(name: Extra.midiTimeCode.name,
                                  values: [.string(timeCode.frameRate.description),
                                           .int(Int(timeCode.ticksPerFrame))]))
        }

        for event in timeline {
            guard case let .meta(eventTime, .smpteOffset(offset)) = event,
                  eventTime == .zero
            else { continue }

            elements.append(Extra(name: Extra.smpteOffset.name,
                                  values: [.string(offset.frameRate.description),
                                           .string(offset.description)]))

            break
        }

        return elements
    }

    // A voice from an unnamed track is named after its first instrument —
    // an Instrument Name meta event's text, else the General MIDI program
    // name, or "Percussion" on channel 10, where the program number doesn't
    // pick a melodic instrument — but only when it has one: that entry's
    // `midiChannel` extra is what `MIDI.Exporter` reads first to recover
    // the channel on export. With no Program Change there's no such extra,
    // so the voice falls back to "Channel N" alone, the exact form
    // `MIDI.Exporter._parseChannelName` reads back instead.
    private static func _makeUnnamedPartName(_ instrumentMap: InstrumentMap<some TimeProtocol>,
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
    private static func _timeline(_ tracks: [MIDI.Track]) -> [MIDI.Event] {
        var timeline: [MIDI.Event] = []

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
