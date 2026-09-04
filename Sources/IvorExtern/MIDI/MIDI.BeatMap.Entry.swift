// © 2025–2026 John Gary Pusey (see LICENSE.md)

internal import IvorTiming
internal import XestiNumbers

extension MIDI.BeatMap {

    // MARK: Internal Nested Types

    internal struct Entry {

        // MARK: Internal Initializers

        internal init(eventTime: MIDI.EventTime,
                      beatTime: BeatTime,
                      factor: Number) {
            self.beatTime = beatTime
            self.eventTime = eventTime
            self.factor = factor
        }

        // MARK: Internal Instance Properties

        internal let beatTime: BeatTime
        internal let eventTime: MIDI.EventTime
        internal let factor: Factor
    }
}

// MARK: - Sendable

extension MIDI.BeatMap.Entry: Sendable {
}
