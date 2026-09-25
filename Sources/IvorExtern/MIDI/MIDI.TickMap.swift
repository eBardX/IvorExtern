// © 2026 John Gary Pusey (see LICENSE.md)

internal import IvorSMF
internal import IvorTiming
internal import XestiNumbers

private import IvorSMPTE

extension MIDI {

    // MARK: Internal Nested Types

    // The exporter's counterpart to `MIDI.BeatMap`: maps beat times to SMF
    // event times. With a metrical division, a beat is a fixed number of
    // ticks. With a timecode division, a tick is a fixed fraction of a
    // second, so a beat time is first converted to seconds through the
    // exact tempo changes the exporter writes — the same ones
    // `MIDI.BeatMap` reads back on import — and only then to ticks, rounding
    // once.
    internal struct TickMap {

        // MARK: Internal Initializers

        internal init(tickRate: MIDI.TickRate) {
            self.entries = []
            self.tickRate = tickRate
            self.ticksPerSecond = nil
        }

        internal init(timeCode: MIDI.TimeCode,
                      tempoChanges: [(beatTime: BeatTime, tempo: MIDI.Tempo)]) {
            var entries: [Entry] = []
            var prevBeatTime = BeatTime.zero
            var prevSeconds = Number(0)
            var prevTempo = MIDI.BeatMap.defaultTempo

            for (beatTime, tempo) in tempoChanges where tempo.uintValue > 0 {
                let seconds = prevSeconds + Self._seconds(beatTime.numberValue - prevBeatTime.numberValue,
                                                          prevTempo)

                entries.append(Entry(beatTime: beatTime,
                                     seconds: seconds,
                                     tempo: tempo.uintValue))

                prevBeatTime = beatTime
                prevSeconds = seconds
                prevTempo = tempo.uintValue
            }

            self.entries = entries
            self.tickRate = nil
            self.ticksPerSecond = timeCode.frameRate.numberValue * Number(timeCode.ticksPerFrame)
        }

        // MARK: Private Instance Properties

        private let entries: [Entry]
        private let tickRate: MIDI.TickRate?
        private let ticksPerSecond: Number?
    }
}

// MARK: -

extension MIDI.TickMap {

    // MARK: Internal Instance Subscripts

    internal subscript(beatTime: BeatTime) -> MIDI.EventTime? {
        if let tickRate {
            return convertToMIDIEventTime(beatTime, tickRate)
        }

        guard let ticksPerSecond
        else { return nil }

        let seconds: Number = if let entry = entries.last(where: { $0.beatTime <= beatTime }) {
            entry.seconds + Self._seconds(beatTime.numberValue - entry.beatTime.numberValue,
                                          entry.tempo)
        } else {
            Self._seconds(beatTime.numberValue,
                          MIDI.BeatMap.defaultTempo)
        }

        let ticks = round(seconds * ticksPerSecond).exact

        guard !ticks.isNegative
        else { return nil }

        return MIDI.EventTime(uintValue: ticks.uintValue)
    }

    // MARK: Private Type Methods

    private static func _seconds(_ quarterNotes: Number,
                                 _ tempo: UInt) -> Number {
        quarterNotes * Number(tempo) / 1_000_000
    }
}

// MARK: - Sendable

extension MIDI.TickMap: Sendable {
}
