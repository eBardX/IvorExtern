// © 2025–2026 John Gary Pusey (see LICENSE.md)

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

    internal func convert(_ sequence: MIDI.Sequence) throws -> Work {
        do {
            return try Self._convert(sequence: sequence)
        } catch let error as any EnhancedError {
            throw MIDI.Error.convertFailure(error)
        }
    }

    internal func convert(_ work: Work) throws -> MIDI.Sequence {
        do {
            return try Self._convert(work: work)
        } catch let error as any EnhancedError {
            throw MIDI.Error.convertFailure(error)
        }
    }

    // MARK: Private Type Properties

    private static let exportTickRate = UInt(480)

    // MARK: Private Type Methods

    private static func _convert(name: String,
                                 tempoMap: TempoMap) throws -> MIDI.Track {
        var events: [SMFEvent] = []

        if !name.isEmpty,
           let smfName = SMFText(stringValue: name) {
            events.append(.meta(.zero, .sequenceTrackName(smfName)))
        }

        if let timeSig = SMFTimeSignature(numerator: 4,
                                          denominator: 2,
                                          clockRate: 24,
                                          beatRate: 8) {
            events.append(.meta(.zero, .timeSignature(timeSig)))
        }

        events += Self._tempoEvents(from: tempoMap)

        events.sort { $0.eventTime < $1.eventTime }

        let endTime = events.map(\.eventTime).max() ?? .zero

        events.append(.meta(endTime, .endOfTrack))

        return MIDI.Track(events: events)
    }

    private static func _convert(part: Part<BeatTime, NoteNumber>) throws -> MIDI.Track {
        let channel = MIDI.Channel(1)
        let kvelOn = MIDI.Note(64)
        let kvalOff = MIDI.Note(0)

        var events: [SMFEvent] = []

        if !part.name.isEmpty,
           let smfName = SMFText(stringValue: part.name) {
            events.append(.meta(.zero, .sequenceTrackName(smfName)))
        }

        var noteError: (any Error)?

        part.noteTable.forEach { btime, bdur, startPitch, _, _ in
            guard noteError == nil
            else { return }

            guard bdur.doubleValue > 0
            else {
                noteError = MIDI.Error.invalidBeatDuration(bdur)

                return
            }

            guard let note = MIDI.Note(uintValue: startPitch.uintValue)
            else {
                noteError = MIDI.Error.invalidNoteNumber(startPitch)

                return
            }

            let attackTime = convertToEventTime(btime, exportTickRate)
            let releaseTime = MIDI.EventTime(UInt(((btime.doubleValue + bdur.doubleValue) * Double(exportTickRate)).rounded()))

            events.append(.midi(attackTime, .noteOn(channel, note, kvelOn)))
            events.append(.midi(releaseTime, .noteOff(channel, note, kvalOff)))
        }

        if let noteError { throw noteError }

        events.sort { $0.eventTime < $1.eventTime }

        let endTime = events.map { $0.eventTime }.max() ?? .zero

        events.append(.meta(endTime, .endOfTrack))

        return MIDI.Track(events: events)
    }

    private static func _convert(parts: [Part<BeatTime, NoteNumber>]) throws -> [MIDI.Track] {
        try parts.map { try _convert(part: $0) }
    }

    private static func _convert(sequence: MIDI.Sequence) throws -> Work {
        guard let track0 = sequence.tracks.first
        else { return Work(name: "",
                           content: .keyboardBeat([],
                                                  TempoMap())) }

        let beatMap = try convertToBeatMap(sequence.division, track0)

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
                    let rawTempo = round(factor * Number(numerator: 60_000_000,
                                                         denominator: tempo.uintValue)).exact
                    let currTempo = Tempo(rawTempo.uintValue)

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
                             division: MIDI.Division.metrical(SMFTickRate(exportTickRate)),
                             tracks: tracks)
    }

    private static func _tempoEvents(from tempoMap: TempoMap) -> [SMFEvent] {
        var events: [SMFEvent] = []

        guard !tempoMap.isEmpty else {
            let usPerQN = 60_000_000 / tempoMap.defaultTempo.uintValue

            if let smfTempo = SMFTempo(uintValue: usPerQN) {
                events.append(.meta(.zero, .tempo(smfTempo)))
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

            let eventTime = convertToEventTime(sampleBeatTime, exportTickRate)
            let usPerQN = 60_000_000 / tempo.uintValue

            if let smfTempo = SMFTempo(uintValue: usPerQN) {
                events.append(.meta(eventTime, .tempo(smfTempo)))

                lastEmittedTempo = tempo
            }
        }

        return events
    }
}

// MARK: - Sendable

extension MIDI.Converter: Sendable {
}
