// © 2026 John Gary Pusey (see LICENSE.md)

internal import IvorModel
internal import IvorTiming
internal import IvorTuning

private import XestiNumbers

// MARK: Internal Functions

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
