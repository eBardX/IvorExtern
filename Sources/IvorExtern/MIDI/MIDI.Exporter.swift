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

    // MARK: Internal Nested Types

    internal struct Exporter {
    }
}

// MARK: -

extension MIDI.Exporter {

    // MARK: Internal Instance Methods

    internal func convert(_ work: Work,
                          options: MIDIExportOptions = MIDIExportOptions()) throws(MIDI.Error) -> MIDI.Sequence {
        guard let tickRate = MIDI.TickRate(uintValue: options.ticksPerQuarterNote)
        else { throw MIDI.Error.invalidTickRate(options.ticksPerQuarterNote) }

        guard let exportTimeCode = MIDI.TimeCode(frameRate: options.timeCodeFrameRate,
                                                 ticksPerFrame: options.ticksPerFrame)
        else { throw MIDI.Error.invalidTimeCode(options.timeCodeFrameRate, options.ticksPerFrame) }

        do {
            return try Self._convert(work: work,
                                     tickRate: tickRate,
                                     exportTimeCode: exportTimeCode)
        } catch let error as any EnhancedError {
            throw MIDI.Error.convertFailure(error)
        } catch {
            throw MIDI.Error.convertFailure(nil)
        }
    }

    // MARK: Private Type Properties

    private static let defaultKeyVelocity = MIDI.KeyVelocity(64)

    // MARK: Private Type Methods

    // Assigns each part a distinct MIDI channel in 1...16, preserving the
    // origin channel a part's own `midiChannel` extra names (see
    // `Extra+Ivor.swift`), so that, for example, a file using channels
    // {1, 5, 9} round-trips back to {1, 5, 9} rather than collapsing to
    // {1, 2, 3} and corrupting the GM channel-10-is-percussion convention.
    //
    // Pass 1: a part whose `midiChannel` extra is in 1...16 claims that
    // channel; on a duplicate claim the first part in array order keeps it,
    // and later claimants fall through to pass 2. Pass 2: every unclaimed
    // part takes the lowest unclaimed channel, in array order. More than 16
    // parts, or an exhausted pool, throws `tooManyParts`.
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

    // A beat-time work imported from a file with a timecode division (see
    // `determineTimeCode`) is written back with the same division; every
    // other beat-time work gets a metrical division at `tickRate`.
    // The work's SMPTE start time is written as an SMPTE Offset (`FF 54`)
    // meta event (see `_smpteOffset`).
    private static func _convert(name: String,
                                 info: Work.Info,
                                 parts: [Part<BeatTime, NoteNumber>],
                                 tempoMap: TempoMap,
                                 meterTable: MeterTable,
                                 timeCode: MIDI.TimeCode?,
                                 tickRate: MIDI.TickRate,
                                 smpteStartTime: SMPTETime) throws(MIDI.Error) -> MIDI.Sequence {
        let division: MIDI.Division = timeCode.map { .timeCode($0) } ?? .metrical(tickRate)
        let tempoChanges = _tempoChanges(from: tempoMap)
        let tickMap = timeCode.map { MIDI.TickMap(timeCode: $0, tempoChanges: tempoChanges) } ?? MIDI.TickMap(tickRate: tickRate)
        var tracks: [MIDI.Track] = []

        try tracks.append(_convert(name: name,
                                   info: info,
                                   smpteOffset: _smpteOffset(smpteStartTime, division),
                                   tempoChanges: tempoChanges,
                                   meterTable: meterTable,
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
    // `exportTimeCode` (by default 25 frames per second at 40 ticks per
    // frame — one tick per millisecond). Its first track carries the work's name and SMPTE
    // Offset (see `_smpteOffset`), but neither tempo nor time signature
    // events.
    private static func _convert(name: String,
                                 info: Work.Info,
                                 parts: [Part<WallTime, NoteNumber>],
                                 timeCode: MIDI.TimeCode?,
                                 exportTimeCode: MIDI.TimeCode,
                                 smpteStartTime: SMPTETime) throws(MIDI.Error) -> MIDI.Sequence {
        let timeCode = timeCode ?? exportTimeCode
        let tickMap = MIDI.WallTickMap(timeCode: timeCode)
        var tracks = [MIDI.Track(events: _headerEvents(name: name,
                                                       info: info,
                                                       smpteOffset: _smpteOffset(smpteStartTime,
                                                                                 .timeCode(timeCode))))]

        tracks += try _convert(parts: parts,
                               tickMap: tickMap)

        return MIDI.Sequence(format: .format1,
                             division: .timeCode(timeCode),
                             tracks: tracks)
    }

    private static func _convert(name: String,
                                 info: Work.Info,
                                 smpteOffset: SMPTETime?,
                                 tempoChanges: [(beatTime: BeatTime, tempo: MIDI.Tempo)],
                                 meterTable: MeterTable,
                                 tickMap: MIDI.TickMap) throws(MIDI.Error) -> MIDI.Track {
        var events = _headerEvents(name: name,
                                   info: info,
                                   smpteOffset: smpteOffset)

        events += _meterEvents(meterTable,
                               tickMap: tickMap)

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

        events += _instrumentEvents(part.instrumentTable, channel: channel, tickMap: tickMap)

        events += _expressionEvents(part.dynamicMap, channel: channel, tickMap: tickMap)

        events += _pedalEvents(part.pedals, channel: channel, tickMap: tickMap)

        // Note-off velocity is the note's `releaseVelocity`, if it has
        // one, or else 64, which MIDI prescribes for a release velocity
        // nobody measured (see `Context.handleNote`). The dynamic at the
        // release time isn't a stand-in: that's a loudness, not how fast the
        // key came up.
        for note in part.noteTable {
            let attTime = note.attack
            let relTime = try tickMap.releaseTime(attack: attTime,
                                                  duration: note.duration)

            guard let noteNumber = convertToMIDINoteNumber(note.startPitch)
            else { throw MIDI.Error.invalidNoteNumber(note.startPitch) }

            if let attEventTime = tickMap.eventTime(at: attTime),
               let relEventTime = tickMap.eventTime(at: relTime) {
                let attKeyVelocity = exactKeyVelocity(note.extras)
                    ?? convertToMIDIKeyVelocity(part.dynamicMap[attTime])
                    ?? defaultKeyVelocity
                let relKeyVelocity = intValue(note.extras, .releaseVelocity)
                    .flatMap { MIDI.KeyVelocity(uintValue: UInt(clamping: $0)) }
                    ?? defaultKeyVelocity

                events.append(.midi(attEventTime, .noteOn(channel, noteNumber, attKeyVelocity)))

                if let value = intValue(note.extras, .midiKeyPressure).flatMap(UInt.init(exactly:)).flatMap(MIDIData1Value.init(uintValue:)) {
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

    private static func _convert(work: Work,
                                 tickRate: MIDI.TickRate,
                                 exportTimeCode: MIDI.TimeCode) throws(MIDI.Error) -> MIDI.Sequence {
        let timeCode = determineTimeCode(work)

        switch work.content {
        case let .keyboardBeat(parts, tempoMap, meterTable):
            return try _convert(name: work.info.title ?? work.name,
                                info: work.info,
                                parts: parts,
                                tempoMap: tempoMap,
                                meterTable: meterTable,
                                timeCode: timeCode,
                                tickRate: tickRate,
                                smpteStartTime: work.smpteStartTime)

        case let .keyboardWall(parts):
            return try _convert(name: work.info.title ?? work.name,
                                info: work.info,
                                parts: parts,
                                timeCode: timeCode,
                                exportTimeCode: exportTimeCode,
                                smpteStartTime: work.smpteStartTime)

        default:
            throw MIDI.Error.unsupportedPitchNotation(work.pitchNotation)
        }
    }

    // `expressionValue` is additive expressive data with no rounding
    // counterpart to fall back to (unlike `attackVelocity`, which always has
    // `Dynamic`'s own re-derivation to fall back to) — emitted only when
    // present, never synthesized.
    private static func _expressionEvents<TickMap: MIDI.ExportTimeMap>(_ dynamicMap: DynamicMap<TickMap.TimeType>,
                                                                       channel: MIDI.Channel,
                                                                       tickMap: TickMap) -> [MIDI.Event] {
        var events: [MIDI.Event] = []

        for entry in dynamicMap {
            if let raw = intValue(entry.extras, .expressionValue).flatMap(UInt.init(exactly:)),
               let eventTime = tickMap.eventTime(at: entry.time) {
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
    // `MIDI.Importer._makeInfo` for the reverse mapping): a Copyright
    // event, which RP-001 places first of all, holding every rights notice,
    // since a file has the one; the work's title, or its name without one;
    // a Text event for the dedication, each credit and each remark, SMF's
    // only home for any of them, with the role or label spelled out (see
    // `describeDedication(_:)`); and the SMPTE Offset, if any. Nothing
    // holds a subtitle, alternate title, or parent work title.
    private static func _headerEvents(name: String,
                                      info: Work.Info,
                                      smpteOffset: SMPTETime?) -> [MIDI.Event] {
        var events: [MIDI.Event] = []

        if !info.rights.isEmpty,
           let copyright = convertToMIDIText(info.rights.map(\.text).joined(separator: "\n")) {
            events.append(.meta(.zero, .copyright(copyright)))
        }

        if let sequenceName = convertToMIDIText(name) {
            events.append(.meta(.zero, .sequenceTrackName(sequenceName)))
        }

        events += _textEvents((info.dedication.map { [describeDedication($0)] } ?? [])
                              + info.credits.map(describeCredit)
                              + info.remarks.map(describeRemark))

        if let smpteOffset {
            events.append(.meta(.zero, .smpteOffset(smpteOffset)))
        }

        return events
    }

    // Emits a Program Change at the part's initial instrument and at every
    // subsequent `instrumentTable` change point. A lookup miss against the
    // General MIDI table omits the directive entirely rather than
    // defaulting to program 0. A `midiProgram` extra overrides the derived
    // program number when present (see `Extra+Ivor.swift`); a
    // `midiBank`/`midiVolume` extra on the entry emits a Bank Select MSB/
    // LSB pair / Channel Volume event immediately before the Program
    // Change, MIDI convention order — the reverse of the combine
    // `MIDI.Importer._makeInstrumentTable` does on the way in. The
    // instrument's display name (its `instrumentName` extra), or failing
    // that its own name, is also written as an Instrument Name (`FF 04`)
    // meta event immediately ahead of the Program Change, unconditionally —
    // the same "always write the resolved name" choice
    // `MusicXML.Exporter`'s own `<score-instrument name=…>` makes — so an
    // explicit name that doesn't match its program's generic General MIDI
    // name (see `MIDI.Importer._makeInstrumentTable`) round-trips rather than
    // silently degrading to that generic name.
    private static func _instrumentEvents<TickMap: MIDI.ExportTimeMap>(_ instrumentTable: InstrumentTable<TickMap.TimeType>,
                                                                       channel: MIDI.Channel,
                                                                       tickMap: TickMap) -> [MIDI.Event] {
        var events: [MIDI.Event] = []

        for entry in instrumentTable {
            let exactProgram = intValue(entry.extras, .midiProgram).flatMap {
                $0 >= 1 ? MIDI.Program(uintValue: UInt($0)) : nil
            }

            if let eventTime = tickMap.eventTime(at: entry.time),
               let program = exactProgram ?? convertToMIDIProgram(entry.instrument) {
                if let bank = intValue(entry.extras, .midiBank).flatMap(UInt.init(exactly:)).flatMap(MIDIBank.init(uintValue:)) {
                    events.append(.midi(eventTime, .controlChange(channel, .bankSelectMSB, bank.msb)))
                    events.append(.midi(eventTime, .controlChange(channel, .bankSelectLSB, bank.lsb)))
                }

                if let volume = doubleValue(entry.extras, .midiVolume),
                   let value = UInt(exactly: (volume / 100.0 * 127.0).rounded()).flatMap(MIDIData1Value.init(uintValue:)) {
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
    // `PanMap` entry. Entries at the same time are a step, so only the last
    // of them is written.
    // One time signature per meter entry, and a marker where it doesn't
    // state the meter exactly (see `makeMeterMarker(_:)`); a meter with no
    // time signature of its own (such as 4/3) repeats the one before it, so
    // that other readers still see a barline there, and a free meter writes
    // the marker alone. A pickup is written as a restart of the first meter
    // where the pickup ends, so that the first bar comes back short. A
    // meterless work is written in 4/4.
    private static func _meterEvents(_ meterTable: MeterTable,
                                     tickMap: MIDI.TickMap) -> [MIDI.Event] {
        guard !meterTable.isEmpty
        else { return [.meta(.zero, .timeSignature(.default))] }

        var entries = meterTable.map { (beatTime: $0.beatTime, meter: $0.meter, extras: $0.extras) }
        var events: [MIDI.Event] = []
        var previous: MIDI.TimeSignature?

        if !meterTable.pickup.isZero,
           let first = entries.first {
            entries.insert((.zero + meterTable.pickup, first.meter, first.extras),
                           at: 1)
        }

        for entry in entries {
            guard let eventTime = tickMap[entry.beatTime]
            else { continue }

            if !entry.meter.isFree {
                let timeSignature = convertToMIDITimeSignature(entry.meter, entry.extras) ?? previous ?? .default

                events.append(.meta(eventTime, .timeSignature(timeSignature)))

                previous = timeSignature
            }

            if let marker = makeMeterMarker(entry.meter) {
                events.append(.meta(eventTime, .marker(marker)))
            }
        }

        return events
    }

    private static func _panEvents<TickMap: MIDI.ExportTimeMap>(_ panMap: PanMap<TickMap.TimeType>,
                                                                channel: MIDI.Channel,
                                                                tickMap: TickMap) -> [MIDI.Event] {
        var entries: [PanMap<TickMap.TimeType>.Entry] = []

        for entry in panMap {
            if entries.last?.time == entry.time {
                entries.removeLast()
            }

            entries.append(entry)
        }

        var events: [MIDI.Event] = []

        for entry in entries {
            guard let eventTime = tickMap.eventTime(at: entry.time)
            else { continue }

            if let raw = intValue(entry.extras, .midiPan).flatMap(UInt.init(exactly:)) {
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

    // Each entry becomes a control change (CC 64–68) at its time, rounded to
    // MIDI's 0–127 scale, in table order — so a re-pedal's Up stays ahead of
    // its Down. Portamento is exported too: only playback holds it back.
    private static func _pedalEvents<TickMap: MIDI.ExportTimeMap>(_ pedals: [Pedal: PedalTable<TickMap.TimeType>],
                                                                  channel: MIDI.Channel,
                                                                  tickMap: TickMap) -> [MIDI.Event] {
        var events: [MIDI.Event] = []

        for pedal in Pedal.allCases {
            for entry in pedals[pedal] ?? PedalTable() {
                guard let eventTime = tickMap.eventTime(at: entry.time)
                else { continue }

                events.append(.midi(eventTime, .controlChange(channel, controller(for: pedal), convertToMIDIValue(entry.level))))
            }
        }

        return events
    }

    // A part's preferred export channel: its `midiChannel` extra, if any.
    private static func _preferredChannel(_ part: Part<some TimeProtocol, NoteNumber>) -> Int? {
        intValue(part.extras, .midiChannel)
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
    // beat time, per the step-change convention).
    private static func _tempoAnchors(_ tempoMap: TempoMap) -> [BeatTime] {
        var beatTimes: [BeatTime] = []

        for entry in tempoMap where beatTimes.last != entry.beatTime {
            beatTimes.append(entry.beatTime)
        }

        return beatTimes
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

        let anchorBeatTimes = _tempoAnchors(tempoMap)

        // Build the ordered list of beat times to sample: the anchors
        // plus every quarter note in the open interval between
        // consecutive anchors.  The quarter notes capture the shape of
        // any smooth accelerando or ritardando between anchors.
        var sampleBeatTimes: [BeatTime] = []

        for (index, beatTime) in anchorBeatTimes.enumerated() {
            sampleBeatTimes.append(beatTime)

            if index + 1 < anchorBeatTimes.count {
                let nextBeatTime = anchorBeatTimes[index + 1]
                let first = Int((beatTime.doubleValue * 4).rounded(.down)) + 1
                let last = Int((nextBeatTime.doubleValue * 4).rounded(.up)) - 1

                if first <= last {
                    for quarter in first...last {
                        sampleBeatTimes.append(BeatTime(Number(numerator: quarter,
                                                               denominator: 4)))
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

            if let midiTempo = convertToMIDITempo(tempo) {
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

    internal var supportedOptions: Set<ExportOptions.Key> {
        [.midiTicksPerQuarterNote, .midiTimeCode]
    }

    internal var writableFileFormats: [FileFormat] {
        [.midi]
    }

    // MARK: Internal Instance Methods

    internal func write(works: [Work],
                        as fileFormat: FileFormat,
                        options: ExportOptions = .default) throws(MIDI.Error) -> FileWrapper {
        switch fileFormat {
        case .midi:
            guard !works.isEmpty
            else { throw MIDI.Error.noWorksToExport }

            guard let work = works.first,
                  works.count == 1
            else { throw MIDI.Error.multipleWorksNotSupported }

            let sequence = try convert(work,
                                       options: options.midi)
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
