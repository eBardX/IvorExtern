// © 2026 John Gary Pusey (see LICENSE.md)

internal import IvorTiming
internal import XestiNumbers

private import IvorSMF
private import IvorSMPTE
private import XestiTools

extension MIDI {

    // MARK: Internal Nested Types

    // The exporter's counterpart to `MIDI.WallMap`: maps wall times to SMF
    // event times under a timecode division, rounding to the nearest tick.
    internal struct WallTickMap {

        // MARK: Internal Initializers

        internal init(timeCode: MIDI.TimeCode) {
            self.ticksPerSecond = timeCode.frameRate.numberValue * Number(timeCode.ticksPerFrame)
        }

        // MARK: Private Instance Properties

        private let ticksPerSecond: Number
    }
}

// MARK: -

extension MIDI.WallTickMap {

    // MARK: Internal Instance Subscripts

    internal subscript(wallTime: WallTime) -> MIDI.EventTime? {
        MIDI.EventTime(uintValue: round(wallTime.numberValue * ticksPerSecond).exact.uintValue)
    }
}

// MARK: - MIDI.ExportTimeMap

extension MIDI.WallTickMap: MIDI.ExportTimeMap {

    // MARK: Internal Instance Methods

    internal func eventTime(at time: WallTime) -> MIDI.EventTime? {
        self[time]
    }

    internal func releaseTime(attack: WallTime,
                              duration: WallDuration) throws(MIDI.Error) -> WallTime {
        guard !duration.isZero
        else { throw MIDI.Error.invalidWallDuration(duration) }

        return attack + duration
    }
}

// MARK: - Sendable

extension MIDI.WallTickMap: Sendable {
}
