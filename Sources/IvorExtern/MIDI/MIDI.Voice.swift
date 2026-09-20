// © 2026 John Gary Pusey (see LICENSE.md)

internal import IvorMIDI

extension MIDI {

    // One (track, channel) pair's paired notes — see
    // `Importer._makeVoices(_:)` for why that, not just the channel, is the
    // grouping key. `panEvents` holds only that channel's `.panMSB` control
    // changes, `programChangeEvents` only its `.programChange` messages, and
    // `bankSelectEvents` only its `.bankSelectMSB`/`.bankSelectLSB` control
    // changes, `expressionEvents` only its `.expressionControllerMSB`/
    // `.expressionControllerLSB` control changes, and `volumeEvents` only
    // its `.channelVolumeMSB` control changes — all filtered out during the
    // same pass that pairs notes — no other channel event is read, so
    // nothing else is kept.
    internal struct Voice {

        // MARK: Internal Instance Properties

        internal let bankSelectEvents: [SMFEvent]
        internal let channel: MIDI.Channel
        internal let expressionEvents: [SMFEvent]
        internal let name: String
        internal let notes: [MIDI.Note]
        internal let panEvents: [SMFEvent]
        internal let programChangeEvents: [SMFEvent]
        internal let volumeEvents: [SMFEvent]
    }
}

// MARK: - Sendable

extension MIDI.Voice: Sendable {
}
