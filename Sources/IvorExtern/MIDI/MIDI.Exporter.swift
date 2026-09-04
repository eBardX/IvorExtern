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
    // origin channel encoded in an unrenamed importer-produced part name
    // (`Part(name: "Channel \(voice.channel.uintValue)", …)`,
    // `MIDI.Importer.swift`) so that, for example, a file using channels
    // {1, 5, 9} round-trips back to {1, 5, 9} rather than collapsing to
    // {1, 2, 3} and corrupting the GM channel-10-is-percussion convention.
    //
    // Pass 1: a name matching `^Channel (\d+)$` with N in 1...16 claims
    // channel N; on a duplicate claim the first part in array order keeps
    // it, and later claimants fall through to pass 2. Pass 2: every
    // unclaimed part takes the lowest unclaimed channel, in array order.
    // More than 16 parts, or an exhausted pool, throws `tooManyParts`.
    //
    // This is inherently fragile: `Part` has no identity field, so
    // renaming a part silently changes its export channel. Worth
    // revisiting if `IvorModel` ever gains one.
    private static func _assignChannels(_ parts: [Part<BeatTime, NoteNumber>]) throws(MIDI.Error) -> [MIDI.Channel] {
        var claimedChannels: [Int: Int] = [:] // part index -> channel number
        var usedChannels: Set<Int> = []

        for (index, part) in parts.enumerated() {
            guard let number = _parseChannelName(part.name),
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

        part.panMap.forEach { _, beatTime, pan, _ in
            if let eventTime = convertToMIDIEventTime(beatTime, exportTickRate),
               let panValue = convertToMIDIPanValue(pan) {
                events.append(.midi(eventTime, .controlChange(channel, .panMSB, panValue)))
            }
        }

        // Emit a Program Change at the part's initial instrument and at
        // every subsequent `instrumentMap` change point. A lookup miss
        // against the General MIDI table omits the directive entirely
        // rather than defaulting to program 0.
        part.instrumentMap.forEach { _, beatTime, instrument, _ in
            if let eventTime = convertToMIDIEventTime(beatTime, exportTickRate),
               let program = convertToMIDIProgramNumber(instrument) {
                events.append(.midi(eventTime, .programChange(channel, program)))
            }
        }

        var noteError: MIDI.Error?

        // Note-off velocity is sampled from `dynamicMap` at the note's
        // *release* time. For a multi-note ramp this yields an
        // interpolated blend rather than a genuine "release velocity"
        // value — MIDI's actual note-off velocity is discarded at import
        // (see `Context.handleNote`) and stored nowhere in the model.
        // Harmless for most playback, but semantically odd; not fixable
        // here without a model change.
        part.noteTable.forEach { _, beatTime, beatDuration, startPitch, _, _ in
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
                let attKeyVelocity = convertToMIDIKeyVelocity(part.dynamicMap[attBeatTime]) ?? defaultKeyVelocity
                let relKeyVelocity = convertToMIDIKeyVelocity(part.dynamicMap[relBeatTime]) ?? defaultKeyVelocity

                events.append(.midi(attEventTime, .noteOn(channel, noteNumber, attKeyVelocity)))
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

    // Parses a part name of the exact form "Channel N", returning N, or
    // `nil` if the name doesn't match (a renamed part, or a part sourced
    // from another importer).
    private static func _parseChannelName(_ name: String) -> Int? {
        let prefix = "Channel "

        guard name.hasPrefix(prefix)
        else { return nil }

        return Int(name.dropFirst(prefix.count))
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
        // beat time, per the step-change convention).
        var anchorBeatTimes: [BeatTime] = []

        tempoMap.forEach { _, beatTime, _, _ in
            if anchorBeatTimes.last != beatTime {
                anchorBeatTimes.append(beatTime)
            }
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

            if let eventTime = convertToMIDIEventTime(sampleBeatTime, exportTickRate),
               let midiTempo = convertToMIDITempo(tempo) {
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
