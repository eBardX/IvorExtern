// © 2026 John Gary Pusey (see LICENSE.md)

internal import IvorModel
internal import IvorTiming
internal import IvorTuning

private import IvorJohnnySonic
private import XestiNumbers

// MARK: Internal Functions

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

// MARK: Internal Functions (Import)

internal func convertToBeatDuration(_ duration: Double) -> BeatDuration {
    BeatDuration(Number(duration))
}

internal func convertToBeatTime(_ beat: Double) -> BeatTime {
    BeatTime(Number(beat))
}

internal func convertToDynamic(_ volume: Double) -> Dynamic? {
    Dynamic(numberValue: Number(volume / 10.0))
}

internal func convertToFrequency(_ pitch: Double) -> Frequency? {
    Frequency(numberValue: Number(-pitch))
}

internal func convertToNoteNumber(_ pitch: Double) -> NoteNumber? {
    guard pitch >= 0
    else { return nil }

    return NoteNumber(uintValue: UInt(pitch.rounded()))
}

internal func convertToPan(_ location: Double) -> Pan? {
    Pan(numberValue: Number(location))
}

internal func convertToTempo(_ bpm: Double) -> Tempo {
    guard bpm.isFinite, bpm > 0
    else { return .default }

    return Tempo(uintValue: UInt(bpm.rounded())) ?? .default
}

// MARK: Internal Functions (Export)

internal func convertToBeat(_ beatTime: BeatTime) -> Double {
    beatTime.doubleValue
}

internal func convertToDuration(_ beatDuration: BeatDuration) -> Double {
    beatDuration.doubleValue
}

internal func convertToLocation(_ pan: Pan) -> Double {
    pan.doubleValue
}

internal func convertToPitch(_ frequency: Frequency) -> Double {
    -frequency.doubleValue
}

internal func convertToPitch(_ noteNumber: NoteNumber) -> Double {
    noteNumber.doubleValue
}

internal func convertToTempo(_ tempo: Tempo) -> Double {
    tempo.doubleValue
}

internal func convertToVolume(_ dynamic: Dynamic) -> Double {
    dynamic.doubleValue * 10
}
