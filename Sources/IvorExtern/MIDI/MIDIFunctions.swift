// © 2025–2026 John Gary Pusey (see LICENSE.md)

internal import IvorModel
internal import IvorTiming
internal import IvorTuning

private import IvorMIDI
private import XestiNumbers
private import XestiTools

// MARK: Internal Functions

internal func convertToDynamic(_ keyVelocity: MIDI.KeyVelocity) -> Dynamic? {
    Dynamic(numberValue: Number(Double(keyVelocity.uintValue) / 127.0))
}

internal func convertToInstrument(_ program: MIDI.ProgramNumber) -> Instrument {
    Instrument(stringValue: generalMIDIInstrumentName(program: Int(program.uintValue))) ?? .vanilla
}

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

internal func convertToMIDIProgramNumber(_ instrument: Instrument) -> MIDI.ProgramNumber? {
    guard let program = generalMIDIProgramNumber(name: instrument.stringValue)
    else { return nil }

    return MIDI.ProgramNumber(uintValue: UInt(program))
}

internal func convertToMIDITempo(_ tempo: Tempo) -> MIDI.Tempo? {
    MIDI.Tempo(uintValue: 60_000_000 / tempo.uintValue)
}

internal func convertToMIDIText(_ text: String) -> MIDI.Text? {
    MIDI.Text(stringValue: text)
}

internal func convertToNoteNumber(_ noteNumber: MIDI.NoteNumber) -> NoteNumber {
    NoteNumber(noteNumber.uintValue)
}

internal func convertToPan(_ panValue: MIDI.PanValue) -> Pan? {
    Pan(numberValue: Number(((Double(panValue.uintValue) / 127.0) * 2.0) - 1.0))
}

internal func convertToTempo(_ tempo: MIDI.Tempo,
                             _ factor: MIDI.BeatMap.Factor) -> Tempo {
    Tempo(round(factor * Number(numerator: 60_000_000,
                                denominator: tempo.uintValue)).exact.uintValue)
}

// Scans one track's own events for its `sequenceTrackName` meta event
// text, or `nil` if it never declared one. `determineWorkName` reads
// track 0's name as the work's name; `MIDI.Importer` reads every other
// track's own name as its `Part`'s name.
internal func determineTrackName(_ track: MIDI.Track) -> String? {
    for event in track.events {
        guard case let .meta(_, .sequenceTrackName(name)) = event
        else { continue }

        return name.stringValue
    }

    return nil
}

internal func determineWorkName(_ sequence: MIDI.Sequence) -> String {
    guard let track0 = sequence.tracks.first
    else { return "" }

    return determineTrackName(track0) ?? ""
}
