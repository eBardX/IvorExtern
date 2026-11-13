// © 2025–2026 John Gary Pusey (see LICENSE.md)

internal import IvorTiming

extension MIDI.BeatMap {

    // MARK: Internal Nested Types

    internal struct Entry {

        // MARK: Internal Initializers

        internal init(eventTime: MIDI.EventTime,
                      beatTime: BeatTime,
                      tempo: UInt) {
            self.beatTime = beatTime
            self.eventTime = eventTime
            self.tempo = tempo
        }

        // MARK: Internal Instance Properties

        internal let beatTime: BeatTime
        internal let eventTime: MIDI.EventTime
        internal let tempo: UInt
    }
}

// MARK: - Sendable

extension MIDI.BeatMap.Entry: Sendable {
}
