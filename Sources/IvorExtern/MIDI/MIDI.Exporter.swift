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

// MARK: - ExporterProtocol

extension MIDI.Exporter: ExporterProtocol {

    // MARK: Internal Instance Properties

    internal var writableFileFormats: [FileFormat] {
        [.midi]
    }

    // MARK: Internal Instance Methods

    internal func write(works: [Work],
                        as fileFormat: FileFormat) throws -> FileWrapper {
        switch fileFormat {
        case .midi:
            guard let work = works.first,
                  works.count == 1
            else { throw MIDI.Error.formatFailure(MIDI.Error.multipleWorksNotSupported) }

            let sequence = try convert(work)
            let data = try MIDI.Formatter().format(sequence)

            return FileWrapper(regularFileWithContents: data)

        default:
            throw MIDI.Error.unsupportedFileFormat(fileFormat.displayName)
        }
    }
}

// MARK: -

extension MIDI.Exporter {

    // MARK: Internal Instance Methods

    internal func convert(_ work: Work) throws -> MIDI.Sequence {
        do {
            return try Self._convert(work: work)
        } catch let error as any EnhancedError {
            throw MIDI.Error.convertFailure(error)
        }
    }

    // MARK: Private Type Properties

    private static let defaultKeyVelocity = MIDI.KeyVelocity(64)
    private static let exportTickRate     = MIDI.TickRate(480)

    // MARK: Private Type Methods

    private static func _convert(name: String,
                                 tempoMap: TempoMap) throws -> MIDI.Track {
        var events: [MIDI.Event] = []

        if let sequenceName = convertToMIDIText(name) {
            events.append(.meta(.zero, .sequenceTrackName(sequenceName)))
        }

        if let timeSig = MIDI.TimeSignature(numerator: 4,
                                            denominator: 2,
                                            clockRate: 24,
                                            beatRate: 8) {
            events.append(.meta(.zero, .timeSignature(timeSig)))
        }

        events += Self._tempoEvents(from: tempoMap)

        events.sort { $0.eventTime < $1.eventTime }

        let endTime = events.map { $0.eventTime }.max() ?? .zero

        events.append(.meta(endTime, .endOfTrack))

        return MIDI.Track(events: events)
    }

    private static func _convert(part: Part<BeatTime, NoteNumber>) throws -> MIDI.Track {
        let channel = MIDI.Channel(1)

        var events: [MIDI.Event] = []

        if let trackName = convertToMIDIText(part.name) {
            events.append(.meta(.zero, .sequenceTrackName(trackName)))
        }

        part.panMap.forEach { beatTime, pan, _ in
            if let eventTime = convertToMIDIEventTime(beatTime, exportTickRate),
               let panValue = convertToMIDIPanValue(pan) {
                events.append(.midi(eventTime, .controlChange(channel, .panMSB, panValue)))
            }
        }

        var noteError: (any Error)?

        part.noteTable.forEach { beatTime, beatDuration, startPitch, _, _ in
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

        events.sort { $0.eventTime < $1.eventTime }

        let endTime = events.map { $0.eventTime }.max() ?? .zero

        events.append(.meta(endTime, .endOfTrack))

        return MIDI.Track(events: events)
    }

    private static func _convert(parts: [Part<BeatTime, NoteNumber>]) throws -> [MIDI.Track] {
        try parts.map { try _convert(part: $0) }
    }

    private static func _convert(work: Work) throws -> MIDI.Sequence {
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

        tempoMap.forEach { beatTime, _, _ in
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

// MARK: - Sendable

extension MIDI.Exporter: Sendable {
}
