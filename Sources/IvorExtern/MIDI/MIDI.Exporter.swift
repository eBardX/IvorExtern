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
    private static let exportTimeCode     = MIDI.TimeCode(frameRate: .fps25,
                                                          ticksPerFrame: 40)!   // swiftlint:disable:this force_unwrapping

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
    private static func _assignChannels(_ parts: [Part<some TimeProtocol, NoteNumber>]) throws(MIDI.Error) -> [MIDI.Channel] {
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
                                 metadata: Work.Metadata,
                                 smpteOffset: SMPTETime?,
                                 tempoChanges: [(beatTime: BeatTime, tempo: MIDI.Tempo)],
                                 tickMap: MIDI.TickMap) throws(MIDI.Error) -> MIDI.Track {
        var events = _headerEvents(name: name,
                                   metadata: metadata,
                                   smpteOffset: smpteOffset)

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

        for (beatTime, tempo) in tempoChanges {
            if let eventTime = tickMap[beatTime] {
                events.append(.meta(eventTime, .tempo(tempo)))
            }
        }

        return MIDI.Track(events: events)
    }

    private static func _convert<TickMap: MIDI.ExportTimeMap>(part: Part<TickMap.TimeType, NoteNumber>,
                                                              channel: MIDI.Channel,
                                                              tickMap: TickMap) throws(MIDI.Error) -> MIDI.Track {
        var events: [MIDI.Event] = []

        if let trackName = convertToMIDIText(part.name) {
            events.append(.meta(.zero, .sequenceTrackName(trackName)))
        }

        events += _panEvents(part.panMap, channel: channel, tickMap: tickMap)

        events += _instrumentEvents(part.instrumentMap, channel: channel, tickMap: tickMap)

        let exactVelocityByTime = _exactVelocityByTime(part.dynamicMap)

        events += _expressionEvents(part.dynamicMap, channel: channel, tickMap: tickMap)

        // Note-off velocity is sampled from `dynamicMap` at the note's
        // *release* time. For a multi-note ramp this yields an
        // interpolated blend rather than a genuine "release velocity"
        // value — MIDI's actual note-off velocity is discarded at import
        // (see `Context.handleNote`) and stored nowhere in the model.
        // Harmless for most playback, but semantically odd; not fixable
        // here without a model change.
        for note in part.noteTable {
            let attTime = note.attack
            let relTime = try tickMap.releaseTime(attack: attTime,
                                                  duration: note.duration)

            guard let noteNumber = convertToMIDINoteNumber(note.startPitch)
            else { throw MIDI.Error.invalidNoteNumber(note.startPitch) }

            if let attEventTime = tickMap.eventTime(at: attTime),
               let relEventTime = tickMap.eventTime(at: relTime) {
                let attKeyVelocity = exactVelocityByTime[attTime]
                    ?? convertToMIDIKeyVelocity(part.dynamicMap[attTime])
                    ?? defaultKeyVelocity
                let relKeyVelocity = exactVelocityByTime[relTime]
                    ?? convertToMIDIKeyVelocity(part.dynamicMap[relTime])
                    ?? defaultKeyVelocity

                events.append(.midi(attEventTime, .noteOn(channel, noteNumber, attKeyVelocity)))

                if let pressure = intValue(note.extras, .midiKeyPressure),
                   let value = MIDIData1Value(uintValue: UInt(pressure)) {
                    events.append(.midi(attEventTime, .polyphonicPressure(channel, noteNumber, value)))
                }

                events.append(.midi(relEventTime, .noteOff(channel, noteNumber, relKeyVelocity)))
            }
        }

        return MIDI.Track(events: events)
    }

    private static func _convert<TickMap: MIDI.ExportTimeMap>(parts: [Part<TickMap.TimeType, NoteNumber>],
                                                              tickMap: TickMap) throws(MIDI.Error) -> [MIDI.Track] {
        let channels = try _assignChannels(parts)
        var tracks: [MIDI.Track] = []

        for (part, channel) in zip(parts, channels) {
            try tracks.append(_convert(part: part,
                                       channel: channel,
                                       tickMap: tickMap))
        }

        return tracks
    }

    // A beat-time work imported from a file with a timecode division (see
    // `determineTimeCode`) is written back with the same division; every
    // other beat-time work gets a metrical division.
    // The work's SMPTE start time is written as an SMPTE Offset (`FF 54`)
    // meta event (see `_smpteOffset`).
    private static func _convert(name: String,
                                 metadata: Work.Metadata,
                                 parts: [Part<BeatTime, NoteNumber>],
                                 tempoMap: TempoMap,
                                 timeCode: MIDI.TimeCode?,
                                 smpteStartTime: SMPTETime) throws(MIDI.Error) -> MIDI.Sequence {
        let division: MIDI.Division = timeCode.map { .timeCode($0) } ?? .metrical(exportTickRate)
        let tempoChanges = _tempoChanges(from: tempoMap)
        let tickMap = timeCode.map { MIDI.TickMap(timeCode: $0, tempoChanges: tempoChanges) } ?? MIDI.TickMap(tickRate: exportTickRate)
        var tracks: [MIDI.Track] = []

        try tracks.append(_convert(name: name,
                                   metadata: metadata,
                                   smpteOffset: _smpteOffset(smpteStartTime, division),
                                   tempoChanges: tempoChanges,
                                   tickMap: tickMap))

        tracks += try _convert(parts: parts,
                               tickMap: tickMap)

        return MIDI.Sequence(format: .format1,
                             division: division,
                             tracks: tracks)
    }

    // A wall-time work is always written with a timecode division, since a
    // metrical one would need a tempo to measure wall time by: the one it
    // was imported with (see `determineTimeCode`), if any, otherwise
    // 25 frames per second at 40 ticks per frame — one tick per
    // millisecond. Its first track carries the work's name and SMPTE
    // Offset (see `_smpteOffset`), but neither tempo nor time signature
    // events.
    private static func _convert(name: String,
                                 metadata: Work.Metadata,
                                 parts: [Part<WallTime, NoteNumber>],
                                 timeCode: MIDI.TimeCode?,
                                 smpteStartTime: SMPTETime) throws(MIDI.Error) -> MIDI.Sequence {
        let timeCode = timeCode ?? exportTimeCode
        let tickMap = MIDI.WallTickMap(timeCode: timeCode)
        var tracks = [MIDI.Track(events: _headerEvents(name: name,
                                                       metadata: metadata,
                                                       smpteOffset: _smpteOffset(smpteStartTime,
                                                                                 .timeCode(timeCode))))]

        tracks += try _convert(parts: parts,
                               tickMap: tickMap)

        return MIDI.Sequence(format: .format1,
                             division: .timeCode(timeCode),
                             tracks: tracks)
    }

    private static func _convert(work: Work) throws(MIDI.Error) -> MIDI.Sequence {
        let timeCode = determineTimeCode(work.content)

        switch work.content {
        case let .keyboardBeat(parts, tempoMap):
            return try _convert(name: work.metadata.title ?? work.name,
                                metadata: work.metadata,
                                parts: parts,
                                tempoMap: tempoMap,
                                timeCode: timeCode,
                                smpteStartTime: work.smpteStartTime)

        case let .keyboardWall(parts):
            return try _convert(name: work.metadata.title ?? work.name,
                                metadata: work.metadata,
                                parts: parts,
                                timeCode: timeCode,
                                smpteStartTime: work.smpteStartTime)

        default:
            throw MIDI.Error.unsupportedPitchNotation(work.pitchNotation)
        }
    }

    // The exact pre-quantization velocity (see `velocity` in
    // `Extra+DynamicMap.swift`) held at each `DynamicMap` entry that carries
    // one, keyed by beat time so the note-emission loop can prefer it over
    // `convertToMIDIKeyVelocity(_:)`'s re-derivation from `Dynamic`.
    private static func _exactVelocityByTime<TimeType: TimeProtocol>(_ dynamicMap: DynamicMap<TimeType>) -> [TimeType: MIDI.KeyVelocity] {
        var result: [TimeType: MIDI.KeyVelocity] = [:]

        for entry in dynamicMap {
            if let velocity = intValue(entry.extras, .velocity),
               let value = MIDI.KeyVelocity(uintValue: UInt(velocity)) {
                result[entry.time] = value
            }
        }

        return result
    }

    // `expressionValue` is additive expressive data with no rounding
    // counterpart to fall back to (unlike `velocity`, which always has
    // `Dynamic`'s own re-derivation to fall back to) — emitted only when
    // present, never synthesized.
    private static func _expressionEvents<TickMap: MIDI.ExportTimeMap>(_ dynamicMap: DynamicMap<TickMap.TimeType>,
                                                                       channel: MIDI.Channel,
                                                                       tickMap: TickMap) -> [MIDI.Event] {
        var events: [MIDI.Event] = []

        for entry in dynamicMap {
            if let expression = intValue(entry.extras, .expressionValue),
               let eventTime = tickMap.eventTime(at: entry.time) {
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

    // The events every exported file's first track opens with (see
    // `MIDI.Importer._makeMetadata` for the reverse mapping): a Copyright
    // event, which RP-001 places first of all, holding every rights notice,
    // since a file has the one; the work's title, or its name without one;
    // a Text event for each credit and each remark, SMF's only home for
    // either, with the role or label spelled out; and the SMPTE Offset, if
    // any. Nothing holds a subtitle, alternate title, or parent work title.
    private static func _headerEvents(name: String,
                                      metadata: Work.Metadata,
                                      smpteOffset: SMPTETime?) -> [MIDI.Event] {
        var events: [MIDI.Event] = []

        if !metadata.rights.isEmpty,
           let copyright = convertToMIDIText(metadata.rights.map(\.text).joined(separator: "\n")) {
            events.append(.meta(.zero, .copyright(copyright)))
        }

        if let sequenceName = convertToMIDIText(name) {
            events.append(.meta(.zero, .sequenceTrackName(sequenceName)))
        }

        events += _textEvents(metadata.credits.map(describeCredit) + metadata.remarks.map(describeRemark))

        if let smpteOffset {
            events.append(.meta(.zero, .smpteOffset(smpteOffset)))
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
    // instrument's display name (its `instrumentName` extra), or failing
    // that its own name, is also written as an Instrument Name (`FF 04`)
    // meta event immediately ahead of the Program Change, unconditionally —
    // the same "always write the resolved name" choice
    // `MusicXML.Exporter`'s own `<score-instrument name=…>` makes — so an
    // explicit name that doesn't match its program's generic General MIDI
    // name (see `MIDI.Importer._makeInstrumentMap`) round-trips rather than
    // silently degrading to that generic name.
    private static func _instrumentEvents<TickMap: MIDI.ExportTimeMap>(_ instrumentMap: InstrumentMap<TickMap.TimeType>,
                                                                       channel: MIDI.Channel,
                                                                       tickMap: TickMap) -> [MIDI.Event] {
        var events: [MIDI.Event] = []

        for entry in instrumentMap {
            let exactProgram = intValue(entry.extras, .midiProgram).flatMap {
                $0 >= 1 ? MIDI.ProgramNumber(uintValue: UInt($0 - 1)) : nil
            }

            if let eventTime = tickMap.eventTime(at: entry.time),
               let program = exactProgram ?? convertToMIDIProgramNumber(entry.instrument) {
                if let bank = intValue(entry.extras, .midiBank), bank >= 1 {
                    let raw = UInt(bank - 1)

                    if let msb = MIDIData1Value(uintValue: raw >> 7),
                       let lsb = MIDIData1Value(uintValue: raw & 0x7f) {
                        events.append(.midi(eventTime, .controlChange(channel, .bankSelectMSB, msb)))
                        events.append(.midi(eventTime, .controlChange(channel, .bankSelectLSB, lsb)))
                    }
                }

                if let volume = doubleValue(entry.extras, .midiVolume),
                   let value = MIDIData1Value(uintValue: UInt((volume / 100.0 * 127.0).rounded())) {
                    events.append(.midi(eventTime, .controlChange(channel, .channelVolumeMSB, value)))
                }

                if let instrumentName = convertToMIDIText(stringValue(entry.extras, .instrumentName) ?? entry.instrument.stringValue) {
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
    private static func _panEvents<TickMap: MIDI.ExportTimeMap>(_ panMap: PanMap<TickMap.TimeType>,
                                                                channel: MIDI.Channel,
                                                                tickMap: TickMap) -> [MIDI.Event] {
        var events: [MIDI.Event] = []

        for entry in panMap {
            guard let eventTime = tickMap.eventTime(at: entry.time)
            else { continue }

            if let midiPan = intValue(entry.extras, .midiPan) {
                let raw = UInt(midiPan)

                if let msb = MIDIData1Value(uintValue: raw >> 7),
                   let lsb = MIDIData1Value(uintValue: raw & 0x7f) {
                    events.append(.midi(eventTime, .controlChange(channel, .panLSB, lsb)))
                    events.append(.midi(eventTime, .controlChange(channel, .panMSB, msb)))
                }
            } else if let panValue = convertToMIDIPanValue(entry.pan) {
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
    private static func _preferredChannel(_ part: Part<some TimeProtocol, NoteNumber>) -> Int? {
        intValue(part.instrumentMap.first?.extras, .midiChannel) ?? _parseChannelName(part.name)
    }

    // The work's SMPTE start time is written as an SMPTE Offset unless
    // it's the one the division implies anyway (see
    // `impliedSMPTEStartTime`), so that a file with no offset gets none
    // back. One whose frame rate SMF can't encode is dropped too, since the
    // formatter would otherwise reject the whole sequence.
    private static func _smpteOffset(_ startTime: SMPTETime,
                                     _ division: MIDI.Division) -> SMPTETime? {
        guard startTime != impliedSMPTEStartTime(division),
              MIDI.TimeCode.supports(startTime.frameRate)
        else { return nil }

        return startTime
    }

    // The distinct beat times in `tempoMap` (last entry wins at any given
    // beat time, per the step-change convention), along with the exact
    // microseconds-per-quarter value (if any) held at each one.
    private static func _tempoAnchors(_ tempoMap: TempoMap) -> (beatTimes: [BeatTime], exactMicroseconds: [BeatTime: Int]) {
        var beatTimes: [BeatTime] = []
        var exactMicroseconds: [BeatTime: Int] = [:]

        for entry in tempoMap {
            if beatTimes.last != entry.beatTime {
                beatTimes.append(entry.beatTime)
            }

            exactMicroseconds[entry.beatTime] = intValue(entry.extras, .midiTempo)
        }

        return (beatTimes, exactMicroseconds)
    }

    private static func _tempoChanges(from tempoMap: TempoMap) -> [(beatTime: BeatTime, tempo: MIDI.Tempo)] {
        var changes: [(beatTime: BeatTime, tempo: MIDI.Tempo)] = []

        guard !tempoMap.isEmpty
        else {
            if let midiTempo = convertToMIDITempo(tempoMap.defaultTempo) {
                changes.append((.zero, midiTempo))
            }

            return changes
        }

        let (anchorBeatTimes, exactMicrosecondsByBeatTime) = _tempoAnchors(tempoMap)

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

            if let midiTempo = exactMidiTempo ?? convertToMIDITempo(tempo) {
                changes.append((sampleBeatTime, midiTempo))

                lastEmittedTempo = tempo
            }
        }

        return changes
    }

    private static func _textEvents(_ texts: [String]) -> [MIDI.Event] {
        texts.compactMap { convertToMIDIText($0).map { .meta(.zero, .text($0)) } }
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
