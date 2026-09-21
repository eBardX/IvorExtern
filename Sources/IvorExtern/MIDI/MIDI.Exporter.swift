// © 2025–2026 John Gary Pusey (see LICENSE.md)

internal import Foundation
internal import IvorModel

private import IvorMIDI
private import IvorTiming
private import IvorTuning
private import XestiNumbers
private import XestiTools

extension MIDI {
    internal struct Exporter {
    }
}

// MARK: -

extension MIDI.Exporter {

    // MARK: Internal Instance Methods

    internal func convert(_ work: Work) throws(MIDI.Error) -> MIDI.Sequence {
        do {
            return try Self._convert(work: work)
        } catch let error as any EnhancedError {
            throw MIDI.Error.convertFailure(error)
        } catch {
            throw MIDI.Error.convertFailure(nil)
        }
    }

    // MARK: Private Type Properties

    private static let defaultKeyVelocity = MIDI.KeyVelocity(64)
    private static let exportTickRate     = MIDI.TickRate(480)

    // MARK: Private Type Methods

    // Assigns each part a distinct MIDI channel in 1...16, preserving the
    // origin channel a part's own `instrumentMap` (a `midiChannel` extra —
    // see `Extra+InstrumentMap.swift`) or, failing that, an unrenamed
    // importer-produced part name (`Part(name: "Channel \(voice.channel.
    // uintValue)", …)`, `MIDI.Importer.swift`) already names, so that, for
    // example, a file using channels {1, 5, 9} round-trips back to
    // {1, 5, 9} rather than collapsing to {1, 2, 3} and corrupting the GM
    // channel-10-is-percussion convention.
    //
    // Pass 1: a part whose `instrumentMap`'s first entry carries a
    // `midiChannel` extra in 1...16, or — failing that — a name matching
    // `^Channel (\d+)$` with N in 1...16, claims channel N; on a duplicate
    // claim the first part in array order keeps it, and later claimants
    // fall through to pass 2. Pass 2: every unclaimed part takes the
    // lowest unclaimed channel, in array order. More than 16 parts, or an
    // exhausted pool, throws `tooManyParts`.
    //
    // This is inherently fragile: `Part` has no identity field, so
    // renaming a part (or clearing its `midiChannel` extra) silently
    // changes its export channel. Worth revisiting if `IvorModel` ever
    // gains one.
    private static func _assignChannels(_ parts: [Part<BeatTime, NoteNumber>]) throws(MIDI.Error) -> [MIDI.Channel] {
        var claimedChannels: [Int: Int] = [:] // part index -> channel number
        var usedChannels: Set<Int> = []

        for (index, part) in parts.enumerated() {
            guard let number = _preferredChannel(part),
                  (1...16).contains(number),
                  !usedChannels.contains(number)
            else { continue }

            claimedChannels[index] = number
            usedChannels.insert(number)
        }

        var nextChannel = 1
        var channelNumbers: [Int] = []

        for index in parts.indices {
            if let number = claimedChannels[index] {
                channelNumbers.append(number)
            } else {
                while usedChannels.contains(nextChannel) {
                    nextChannel += 1
                }

                guard nextChannel <= 16
                else { throw MIDI.Error.tooManyParts(parts.count) }

                channelNumbers.append(nextChannel)
                usedChannels.insert(nextChannel)
            }
        }

        var channels: [MIDI.Channel] = []

        for number in channelNumbers {
            guard let channel = MIDI.Channel(uintValue: UInt(number))
            else { throw MIDI.Error.tooManyParts(parts.count) }

            channels.append(channel)
        }

        return channels
    }

    private static func _convert(name: String,
                                 tempoMap: TempoMap) throws(MIDI.Error) -> MIDI.Track {
        var events: [MIDI.Event] = []

        if let sequenceName = convertToMIDIText(name) {
            events.append(.meta(.zero, .sequenceTrackName(sequenceName)))
        }

        // Always 4/4: a model-level limitation, not an exporter shortcut.
        // `Work` has no field to store a time signature — the importer
        // already discards whatever the source SMF carried — so there is
        // nothing here for the exporter to recover.
        if let timeSig = MIDI.TimeSignature(numerator: 4,
                                            denominator: 2,
                                            clockRate: 24,
                                            beatRate: 8) {
            events.append(.meta(.zero, .timeSignature(timeSig)))
        }

        events += Self._tempoEvents(from: tempoMap)

        return MIDI.Track(events: events)
    }

    private static func _convert(part: Part<BeatTime, NoteNumber>,
                                 channel: MIDI.Channel) throws(MIDI.Error) -> MIDI.Track {
        var events: [MIDI.Event] = []

        if let trackName = convertToMIDIText(part.name) {
            events.append(.meta(.zero, .sequenceTrackName(trackName)))
        }

        events += _panEvents(part.panMap, channel: channel)

        events += _instrumentEvents(part.instrumentMap, channel: channel)

        let exactVelocityByBeatTime = _exactVelocityByBeatTime(part.dynamicMap)

        events += _expressionEvents(part.dynamicMap, channel: channel)

        var noteError: MIDI.Error?

        // Note-off velocity is sampled from `dynamicMap` at the note's
        // *release* time. For a multi-note ramp this yields an
        // interpolated blend rather than a genuine "release velocity"
        // value — MIDI's actual note-off velocity is discarded at import
        // (see `Context.handleNote`) and stored nowhere in the model.
        // Harmless for most playback, but semantically odd; not fixable
        // here without a model change.
        part.noteTable.forEach { _, beatTime, beatDuration, startPitch, _, extras in
            guard noteError == nil
            else { return }

            guard beatDuration > 0
            else { noteError = MIDI.Error.invalidBeatDuration(beatDuration); return }

            guard let noteNumber = convertToMIDINoteNumber(startPitch)
            else { noteError = MIDI.Error.invalidNoteNumber(startPitch); return }

            let attBeatTime = beatTime
            let relBeatTime = beatTime + beatDuration

            if let attEventTime = convertToMIDIEventTime(beatTime, exportTickRate),
               let relEventTime = convertToMIDIEventTime(beatTime + beatDuration, exportTickRate) {
                let attKeyVelocity = exactVelocityByBeatTime[attBeatTime]
                    ?? convertToMIDIKeyVelocity(part.dynamicMap[attBeatTime])
                    ?? defaultKeyVelocity
                let relKeyVelocity = exactVelocityByBeatTime[relBeatTime]
                    ?? convertToMIDIKeyVelocity(part.dynamicMap[relBeatTime])
                    ?? defaultKeyVelocity

                events.append(.midi(attEventTime, .noteOn(channel, noteNumber, attKeyVelocity)))

                if let pressure = intValue(extras, .midiKeyPressure),
                   let value = MIDIData1Value(uintValue: UInt(pressure)) {
                    events.append(.midi(attEventTime, .polyphonicPressure(channel, noteNumber, value)))
                }

                events.append(.midi(relEventTime, .noteOff(channel, noteNumber, relKeyVelocity)))
            }
        }

        if let noteError {
            throw noteError
        }

        return MIDI.Track(events: events)
    }

    private static func _convert(parts: [Part<BeatTime, NoteNumber>]) throws(MIDI.Error) -> [MIDI.Track] {
        let channels = try _assignChannels(parts)
        var tracks: [MIDI.Track] = []

        for (part, channel) in zip(parts, channels) {
            try tracks.append(_convert(part: part,
                                       channel: channel))
        }

        return tracks
    }

    private static func _convert(work: Work) throws(MIDI.Error) -> MIDI.Sequence {
        var tracks: [MIDI.Track] = []

        if let tempoMap = work.tempoMap {
            try tracks.append(_convert(name: work.name,
                                       tempoMap: tempoMap))
        }

        switch work.content {
        case .absoluteBeat,
             .standardBeat:
            throw MIDI.Error.unsupportedPitchNotation(work.pitchNotation)

        case let .keyboardBeat(parts, _):
            tracks += try _convert(parts: parts)

        default:
            throw MIDI.Error.unsupportedTimeBasis(work.timeBasis)
        }

        return MIDI.Sequence(format: .format1,
                             division: MIDI.Division.metrical(exportTickRate),
                             tracks: tracks)
    }

    // The exact pre-quantization velocity (see `velocity` in
    // `Extra+DynamicMap.swift`) held at each `DynamicMap` entry that carries
    // one, keyed by beat time so the note-emission loop can prefer it over
    // `convertToMIDIKeyVelocity(_:)`'s re-derivation from `Dynamic`.
    private static func _exactVelocityByBeatTime(_ dynamicMap: DynamicMap<BeatTime>) -> [BeatTime: MIDI.KeyVelocity] {
        var result: [BeatTime: MIDI.KeyVelocity] = [:]

        dynamicMap.forEach { _, beatTime, _, extras in
            if let velocity = intValue(extras, .velocity),
               let value = MIDI.KeyVelocity(uintValue: UInt(velocity)) {
                result[beatTime] = value
            }
        }

        return result
    }

    // `expressionValue` is additive expressive data with no rounding
    // counterpart to fall back to (unlike `velocity`, which always has
    // `Dynamic`'s own re-derivation to fall back to) — emitted only when
    // present, never synthesized.
    private static func _expressionEvents(_ dynamicMap: DynamicMap<BeatTime>, channel: MIDI.Channel) -> [MIDI.Event] {
        var events: [MIDI.Event] = []

        dynamicMap.forEach { _, beatTime, _, extras in
            if let expression = intValue(extras, .expressionValue),
               let eventTime = convertToMIDIEventTime(beatTime, exportTickRate) {
                let raw = UInt(expression)

                if let msb = MIDIData1Value(uintValue: raw >> 7),
                   let lsb = MIDIData1Value(uintValue: raw & 0x7f) {
                    events.append(.midi(eventTime, .controlChange(channel, .expressionControllerMSB, msb)))
                    events.append(.midi(eventTime, .controlChange(channel, .expressionControllerLSB, lsb)))
                }
            }
        }

        return events
    }

    // Emits a Program Change at the part's initial instrument and at every
    // subsequent `instrumentMap` change point. A lookup miss against the
    // General MIDI table omits the directive entirely rather than
    // defaulting to program 0. A `midiProgram` extra overrides the derived
    // program number when present (see `Extra+InstrumentMap.swift`); a
    // `midiBank`/`midiVolume` extra on the entry emits a Bank Select MSB/
    // LSB pair / Channel Volume event immediately before the Program
    // Change, MIDI convention order — the reverse of the combine
    // `MIDI.Importer._makeInstrumentMap` does on the way in. The
    // instrument's own name is also written as an Instrument Name (`FF 04`)
    // meta event immediately ahead of the Program Change, unconditionally —
    // the same "always write the resolved name" choice
    // `MusicXML.Exporter`'s own `<score-instrument name=…>` makes — so an
    // explicit name that doesn't match its program's generic General MIDI
    // name (see `MIDI.Importer._makeInstrumentMap`) round-trips rather than
    // silently degrading to that generic name.
    private static func _instrumentEvents(_ instrumentMap: InstrumentMap<BeatTime>, channel: MIDI.Channel) -> [MIDI.Event] {
        var events: [MIDI.Event] = []

        instrumentMap.forEach { _, beatTime, instrument, extras in
            let exactProgram = intValue(extras, .midiProgram).flatMap {
                $0 >= 1 ? MIDI.ProgramNumber(uintValue: UInt($0 - 1)) : nil
            }

            if let eventTime = convertToMIDIEventTime(beatTime, exportTickRate),
               let program = exactProgram ?? convertToMIDIProgramNumber(instrument) {
                if let bank = intValue(extras, .midiBank), bank >= 1 {
                    let raw = UInt(bank - 1)

                    if let msb = MIDIData1Value(uintValue: raw >> 7),
                       let lsb = MIDIData1Value(uintValue: raw & 0x7f) {
                        events.append(.midi(eventTime, .controlChange(channel, .bankSelectMSB, msb)))
                        events.append(.midi(eventTime, .controlChange(channel, .bankSelectLSB, lsb)))
                    }
                }

                if let volume = doubleValue(extras, .midiVolume),
                   let value = MIDIData1Value(uintValue: UInt((volume / 100.0 * 127.0).rounded())) {
                    events.append(.midi(eventTime, .controlChange(channel, .channelVolumeMSB, value)))
                }

                if let instrumentName = convertToMIDIText(instrument.stringValue) {
                    events.append(.meta(eventTime, .instrumentName(instrumentName)))
                }

                events.append(.midi(eventTime, .programChange(channel, program)))
            }
        }

        return events
    }

    // `midiPan`, when present, is the exact combined 14-bit value — split
    // back into an LSB/MSB pair, rather than re-deriving a 7-bit-only value
    // from `Pan`. LSB is emitted first (unlike Bank Select's MSB-then-LSB
    // convention) so `MIDI.Importer`'s same-tick merge — which reads events
    // in emission order, not MIDI-standard byte order — already knows the
    // LSB by the time it processes the MSB that actually creates the
    // `PanMap` entry.
    private static func _panEvents(_ panMap: PanMap<BeatTime>, channel: MIDI.Channel) -> [MIDI.Event] {
        var events: [MIDI.Event] = []

        panMap.forEach { _, beatTime, pan, extras in
            guard let eventTime = convertToMIDIEventTime(beatTime, exportTickRate)
            else { return }

            if let midiPan = intValue(extras, .midiPan) {
                let raw = UInt(midiPan)

                if let msb = MIDIData1Value(uintValue: raw >> 7),
                   let lsb = MIDIData1Value(uintValue: raw & 0x7f) {
                    events.append(.midi(eventTime, .controlChange(channel, .panLSB, lsb)))
                    events.append(.midi(eventTime, .controlChange(channel, .panMSB, msb)))
                }
            } else if let panValue = convertToMIDIPanValue(pan) {
                events.append(.midi(eventTime, .controlChange(channel, .panMSB, panValue)))
            }
        }

        return events
    }

    // Parses a part name of the exact form "Channel N", returning N, or
    // `nil` if the name doesn't match (a renamed part, or a part sourced
    // from another importer).
    private static func _parseChannelName(_ name: String) -> Int? {
        let prefix = "Channel "

        guard name.hasPrefix(prefix)
        else { return nil }

        return Int(name.dropFirst(prefix.count))
    }

    // A part's preferred export channel: its `instrumentMap`'s first
    // entry's `midiChannel` extra, if any, otherwise the "Channel N" name
    // convention `_parseChannelName(_:)` reads.
    private static func _preferredChannel(_ part: Part<BeatTime, NoteNumber>) -> Int? {
        var firstExtras: Extras?
        var seen = false

        part.instrumentMap.forEach { _, _, _, extras in
            if !seen {
                firstExtras = extras
                seen = true
            }
        }

        return intValue(firstExtras, .midiChannel) ?? _parseChannelName(part.name)
    }

    private static func _tempoEvents(from tempoMap: TempoMap) -> [MIDI.Event] {
        var events: [SMFEvent] = []

        guard !tempoMap.isEmpty
        else {
            if let midiTempo = convertToMIDITempo(tempoMap.defaultTempo) {
                events.append(.meta(.zero, .tempo(midiTempo)))
            }

            return events
        }

        // Collect the distinct beat times (last entry wins at any given
        // beat time, per the step-change convention), along with the exact
        // microseconds-per-quarter value (if any) held at each one.
        var anchorBeatTimes: [BeatTime] = []
        var exactMicrosecondsByBeatTime: [BeatTime: Int] = [:]

        tempoMap.forEach { _, beatTime, _, extras in
            if anchorBeatTimes.last != beatTime {
                anchorBeatTimes.append(beatTime)
            }

            exactMicrosecondsByBeatTime[beatTime] = intValue(extras, .midiTempo)
        }

        // Build the ordered list of beat times to sample: the anchors
        // plus every integer beat in the open interval between
        // consecutive anchors.  The integer beats capture the shape of
        // any smooth accelerando or ritardando between anchors.
        var sampleBeatTimes: [BeatTime] = []

        for (index, beatTime) in anchorBeatTimes.enumerated() {
            sampleBeatTimes.append(beatTime)

            if index + 1 < anchorBeatTimes.count {
                let nextBeatTime = anchorBeatTimes[index + 1]
                let first = Int(beatTime.doubleValue.rounded(.down)) + 1
                let last = Int(nextBeatTime.doubleValue.rounded(.up)) - 1

                if first <= last {
                    for beat in first...last {
                        sampleBeatTimes.append(BeatTime(Number(beat)))
                    }
                }
            }
        }

        // Emit one tempo event per sample, suppressing consecutive
        // entries with the same tempo.
        var lastEmittedTempo: Tempo?

        for sampleBeatTime in sampleBeatTimes {
            let tempo = tempoMap[sampleBeatTime]

            guard tempo != lastEmittedTempo
            else { continue }

            let exactMidiTempo = exactMicrosecondsByBeatTime[sampleBeatTime].flatMap { MIDI.Tempo(uintValue: UInt($0)) }

            if let eventTime = convertToMIDIEventTime(sampleBeatTime, exportTickRate),
               let midiTempo = exactMidiTempo ?? convertToMIDITempo(tempo) {
                events.append(.meta(eventTime, .tempo(midiTempo)))

                lastEmittedTempo = tempo
            }
        }

        return events
    }
}

// MARK: - ExporterProtocol

extension MIDI.Exporter: ExporterProtocol {

    // MARK: Internal Instance Properties

    internal var writableFileFormats: [FileFormat] {
        [.midi]
    }

    // MARK: Internal Instance Methods

    internal func write(works: [Work],
                        as fileFormat: FileFormat) throws(MIDI.Error) -> FileWrapper {
        switch fileFormat {
        case .midi:
            guard !works.isEmpty
            else { throw MIDI.Error.noWorksToExport }

            guard let work = works.first,
                  works.count == 1
            else { throw MIDI.Error.multipleWorksNotSupported }

            let sequence = try convert(work)
            let data = try MIDI.Formatter().format(sequence)

            return FileWrapper(regularFileWithContents: data)

        default:
            throw MIDI.Error.unsupportedFileFormat(fileFormat.displayName)
        }
    }
}

// MARK: - Sendable

extension MIDI.Exporter: Sendable {
}
