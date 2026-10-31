// © 2026 John Gary Pusey (see LICENSE.md)

internal import IvorABC
internal import IvorModel

extension ABC {

    // The instrument a `%%MIDI voice` directive assigns (see
    // `convertToVoiceInstrument(_:)`). `program` counts from 1, like the
    // `midiProgram` extra, and `bank` from 0, like the `midiBank` extra.
    // `voiceID` is `nil` when the directive names no voice.
    internal struct VoiceInstrument {

        // MARK: Internal Instance Properties

        internal let bank: Int?
        internal let instrument: Instrument
        internal let program: Int
        internal let voiceID: ABC.Voice.ID?
    }
}

// MARK: - Sendable

extension ABC.VoiceInstrument: Sendable {
}
