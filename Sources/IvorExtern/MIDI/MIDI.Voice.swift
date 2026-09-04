// © 2026 John Gary Pusey (see LICENSE.md)

internal import IvorMIDI

extension MIDI {

    // One (track, channel) pair's paired notes — see
    // `Importer._makeVoices(_:)` for why that, not just the channel, is the
    // grouping key. `panEvents` holds only that channel's `.panMSB` control
    // changes and `programChangeEvents` only its `.programChange` messages,
    // both filtered out during the same pass that pairs notes — no other
    // channel event is read, so nothing else is kept.
    internal struct Voice {

        // MARK: Internal Instance Properties

        internal let channel: MIDI.Channel
        internal let name: String
        internal let notes: [MIDI.Note]
        internal let panEvents: [SMFEvent]
        internal let programChangeEvents: [SMFEvent]
    }
}

// MARK: - Sendable

extension MIDI.Voice: Sendable {
}
