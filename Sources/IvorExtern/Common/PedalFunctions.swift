// © 2026 John Gary Pusey (see LICENSE.md)

internal import IvorMIDI
internal import IvorModel
internal import IvorTiming

private import XestiNumbers

// MARK: Internal Functions

// The MIDI controller that carries `pedal` (CC 64–68).
internal func controller(for pedal: Pedal) -> MIDIController {
    switch pedal {
    case .legato:
        .legato

    case .portamento:
        .portamento

    case .soft:
        .softPedal

    case .sostenuto:
        .sostenuto

    case .sustain:
        .sustain
    }
}

// Rounded to the nearest value on MIDI's 0–127 scale.
internal func convertToMIDIValue(_ level: Pedal.Level) -> MIDIData1Value {
    MIDIData1Value(clamping: Int((level.doubleValue * 127).rounded()))
}

// The pedal that `controller` carries, or `nil` if it isn't one of CC 64–68.
internal func convertToPedal(_ controller: MIDIController) -> Pedal? {
    Pedal.allCases.first { IvorExtern.controller(for: $0) == controller }
}

// Exact, with no snapping: a half-pedaling device's 64 imports as 64/127, and
// a switch's 0 and 127 as exactly `.off` and `.on`.
internal func convertToPedalLevel(midiValue: MIDIData1Value) -> Pedal.Level {
    Pedal.Level(Number(numerator: Int(midiValue.uintValue),
                       denominator: 127))
}

// MusicXML's 0–100 scale, as in `<sound damper-pedal="50">`. A value outside
// it is clamped, and a fractional one is kept to a thousandth of a percent.
internal func convertToPedalLevel(percent: Double) -> Pedal.Level {
    let clamped = min(max(percent, 0), 100)

    return Pedal.Level(Number(numerator: Int((clamped * 1_000).rounded()),
                              denominator: 100_000))
}

// Consecutive entries at the same time, in table order.
internal func groupedByTime<TimeType: TimeProtocol>(_ table: PedalTable<TimeType>) -> [(time: TimeType, levels: [Pedal.Level])] {
    var groups: [(time: TimeType, levels: [Pedal.Level])] = []

    for entry in table {
        if let last = groups.last, last.time == entry.time {
            groups[groups.count - 1].levels.append(entry.level)
        } else {
            groups.append((time: entry.time, levels: [entry.level]))
        }
    }

    return groups
}

// What a format with only a down/up pedal switch must write for one time's
// entries, given the level before them, thresholded at `Pedal.Level.isDown`:
// `[true]` where the pedal goes down, `[false]` where it comes up,
// `[false, true]` for a re-pedal (down before and after, with an up in
// between), and nothing otherwise.
internal func pedalSwitches(after previous: Pedal.Level,
                            _ levels: [Pedal.Level]) -> [Bool] {
    guard let final = levels.last
    else { return [] }

    switch (previous.isDown, final.isDown) {
    case (false, true):
        return [true]

    case (true, false):
        return [false]

    case (true, true) where levels.contains { !$0.isDown }:
        return [false, true]

    default:
        return []
    }
}
