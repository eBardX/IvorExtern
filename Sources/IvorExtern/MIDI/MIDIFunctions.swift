// © 2025–2026 John Gary Pusey (see LICENSE.md)

internal import IvorModel
internal import IvorTiming
internal import IvorTuning

private import IvorMIDI
private import XestiNumbers
private import XestiTools

// MARK: Internal Functions

internal func convertToMIDIEventTime(_ beatTime: BeatTime,
                                     _ tickRate: MIDI.TickRate) -> MIDI.EventTime? {
    MIDI.EventTime(uintValue: UInt((beatTime.doubleValue * Double(tickRate.uintValue)).rounded()))
}

internal func convertToMIDIKeyVelocity(_ dynamic: Dynamic) -> MIDI.KeyVelocity? {
    MIDI.KeyVelocity(uintValue: max(1, UInt((dynamic.doubleValue * 127.0).rounded())))
}

internal func convertToMIDINoteNumber(_ pitch: NoteNumber) -> MIDI.NoteNumber? {
    MIDI.NoteNumber(uintValue: pitch.uintValue)
}

internal func convertToMIDIPanValue(_ pan: Pan) -> MIDI.PanValue? {
    MIDI.PanValue(uintValue: UInt((((pan.doubleValue + 1.0) / 2.0) * 127.0).rounded()))
}

internal func convertToMIDITempo(_ tempo: Tempo) -> MIDI.Tempo? {
    MIDI.Tempo(uintValue: 60_000_000 / tempo.uintValue)
}

internal func convertToMIDIText(_ text: String) -> MIDI.Text? {
    MIDI.Text(stringValue: text)
}

internal func determineWorkName(_ sequence: MIDI.Sequence) -> String {
    guard let track0 = sequence.tracks.first
    else { return "" }

    for event in track0.events {
        switch event {
        case let .meta(_, message):
            switch message {
            case let .sequenceTrackName(name):
                return name.stringValue

            default:
                break
            }

        default:
            break
        }
    }

    return ""
}
