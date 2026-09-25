// © 2026 John Gary Pusey (see LICENSE.md)

internal import IvorTiming
internal import XestiNumbers

extension MIDI.TickMap {

    // MARK: Internal Nested Types

    internal struct Entry {

        // MARK: Internal Initializers

        internal init(beatTime: BeatTime,
                      seconds: Number,
                      tempo: UInt) {
            self.beatTime = beatTime
            self.seconds = seconds
            self.tempo = tempo
        }

        // MARK: Internal Instance Properties

        internal let beatTime: BeatTime
        internal let seconds: Number
        internal let tempo: UInt
    }
}

// MARK: - Sendable

extension MIDI.TickMap.Entry: Sendable {
}
