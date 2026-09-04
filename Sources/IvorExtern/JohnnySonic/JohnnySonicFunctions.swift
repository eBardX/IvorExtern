// © 2026 John Gary Pusey (see LICENSE.md)

internal import IvorModel
internal import IvorTiming
internal import IvorTuning

private import IvorJohnnySonic
private import XestiNumbers

// MARK: Internal Functions

internal func convertToBeatDuration(_ duration: Double) -> BeatDuration {
    BeatDuration(Number(duration))
}

internal func convertToBeatTime(_ beat: Double) -> BeatTime {
    BeatTime(Number(beat))
}

internal func convertToDynamic(_ volume: Double) -> Dynamic? {
    Dynamic(numberValue: Number(volume / 10.0))
}

// Takes a frequency already in Hz — `JohnnySonic.Importer.Tuning`, not this
// function, is what turns a raw JohnnySonic pitch (positive = pitch number,
// negative = frequency in Hz) into Hz.
internal func convertToFrequency(_ hertz: Double) -> Frequency? {
    Frequency(numberValue: Number(hertz))
}

internal func convertToInstrument(_ name: String) -> Instrument? {
    Instrument(stringValue: name)
}

internal func convertToJohnnySonicBeat(_ beatTime: BeatTime) -> JohnnySonic.Beat {
    beatTime.doubleValue
}

internal func convertToJohnnySonicDuration(_ beatDuration: BeatDuration) -> JohnnySonic.Duration {
    beatDuration.doubleValue
}

internal func convertToJohnnySonicLocation(_ pan: Pan) -> JohnnySonic.Location {
    pan.doubleValue
}

internal func convertToJohnnySonicPitch(_ frequency: Frequency) -> JohnnySonic.Pitch {
    -frequency.doubleValue
}

internal func convertToJohnnySonicPitch(_ noteNumber: NoteNumber) -> JohnnySonic.Pitch {
    noteNumber.doubleValue
}

internal func convertToJohnnySonicTempo(_ tempo: Tempo) -> JohnnySonic.Tempo {
    tempo.doubleValue
}

internal func convertToJohnnySonicVolume(_ dynamic: Dynamic) -> JohnnySonic.Volume {
    dynamic.doubleValue * 10
}

internal func convertToNoteNumber(_ pitch: Double) -> NoteNumber? {
    guard pitch >= 0
    else { return nil }

    return NoteNumber(uintValue: UInt(pitch.rounded()))
}

internal func convertToPan(_ location: JohnnySonic.Location) -> Pan? {
    Pan(numberValue: Number(location))
}

internal func convertToTempo(_ bpm: Double) -> Tempo {
    guard bpm.isFinite, bpm > 0
    else { return .default }

    return Tempo(uintValue: UInt(bpm.rounded())) ?? .default
}

internal func determineWorkName(_ score: JohnnySonic.Score) -> String {
    let prefix = "| Work: "
    let suffix = " |"

    for command in score.commands {
        guard case let .comment(text) = command
        else { continue }

        if text.hasPrefix(prefix), text.hasSuffix(suffix) {
            return String(text.dropFirst(prefix.count).dropLast(suffix.count))
        }
    }

    return ""
}
