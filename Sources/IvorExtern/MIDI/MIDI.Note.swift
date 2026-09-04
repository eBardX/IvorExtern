// © 2026 John Gary Pusey (see LICENSE.md)

private import IvorMIDI

extension MIDI {

    // A sounding note produced by pairing a note-on with its matching
    // note-off. Unlike the upstream playback model's equivalent type, this
    // one has no access restriction on its initializer, so `@testable` unit
    // tests can construct one directly.
    internal struct Note {

        // MARK: Internal Instance Properties

        internal let duration: UInt
        internal let key: MIDI.NoteNumber
        internal let offVelocity: MIDI.KeyVelocity
        internal let onVelocity: MIDI.KeyVelocity
        internal let startTime: MIDI.EventTime
    }
}

// MARK: - Sendable

extension MIDI.Note: Sendable {
}
