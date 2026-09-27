// © 2026 John Gary Pusey (see LICENSE.md)

internal import IvorTiming
internal import XestiNumbers

private import IvorSMF
private import IvorSMPTE
private import XestiTools

extension MIDI {

    // MARK: Internal Nested Types

    // The wall-time counterpart to `MIDI.BeatMap`, for a file with a
    // timecode division and no tempo events: a tick is a fixed fraction of a
    // second — one exact division by the frame rate and ticks per frame — so
    // an event time maps straight to a wall time, rounded to the nearest
    // microsecond.
    internal struct WallMap {

        // MARK: Internal Initializers

        internal init(timeCode: MIDI.TimeCode) {
            self.ticksPerSecond = timeCode.frameRate.numberValue * Number(timeCode.ticksPerFrame)
        }

        // MARK: Private Instance Properties

        private let ticksPerSecond: Number
    }
}

// MARK: -

extension MIDI.WallMap {

    // MARK: Internal Instance Subscripts

    internal subscript(eventTime: MIDI.EventTime) -> WallTime {
        WallTime(round(Number(eventTime.uintValue) * 1_000_000 / ticksPerSecond).exact.uintValue)
    }
}

// MARK: - MIDI.ImportTimeMap

extension MIDI.WallMap: MIDI.ImportTimeMap {

    // MARK: Internal Instance Methods

    internal func time(at eventTime: MIDI.EventTime) -> WallTime {
        self[eventTime]
    }

    internal func timeSpan(at eventTime: MIDI.EventTime,
                           ticks: UInt) -> (WallTime, WallDuration) {
        let attack = self[eventTime]
        let release = self[MIDI.EventTime(eventTime.uintValue + ticks)]

        return (attack, release - attack)
    }
}

// MARK: - Sendable

extension MIDI.WallMap: Sendable {
}
