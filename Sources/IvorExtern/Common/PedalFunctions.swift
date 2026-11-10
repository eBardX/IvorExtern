// © 2026 John Gary Pusey (see LICENSE.md)

internal import IvorMIDI
internal import IvorModel
internal import IvorTiming
internal import IvorTuning

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
// a switch's 0 and 127 as exactly `.up` and `.down`.
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

// `work` with every part's pedal tables simplified by `mode` (see
// `PedalTable.simplify(_:)`), for the `pedalSimplification` import option.
internal func simplifyingPedals(of work: Work,
                                _ mode: Pedal.SimplifyMode) throws -> Work {
    var work = work

    switch work.content {
    case let .absoluteBeat(parts, tempoMap):
        try work.replaceContent(with: .absoluteBeat(_simplifyingPedals(of: parts, mode), tempoMap))

    case let .absoluteWall(parts):
        try work.replaceContent(with: .absoluteWall(_simplifyingPedals(of: parts, mode)))

    case let .keyboardBeat(parts, tempoMap):
        try work.replaceContent(with: .keyboardBeat(_simplifyingPedals(of: parts, mode), tempoMap))

    case let .keyboardWall(parts):
        try work.replaceContent(with: .keyboardWall(_simplifyingPedals(of: parts, mode)))

    case let .standardBeat(parts, tempoMap):
        try work.replaceContent(with: .standardBeat(_simplifyingPedals(of: parts, mode), tempoMap))

    case let .standardWall(parts):
        try work.replaceContent(with: .standardWall(_simplifyingPedals(of: parts, mode)))
    }

    return work
}

// MARK: Private Functions

private func _simplifyingPedals<T: TimeProtocol, P: PitchProtocol>(of parts: [Part<T, P>],
                                                                   _ mode: Pedal.SimplifyMode) -> [Part<T, P>] {
    parts.map { part in
        var part = part

        part.pedals = part.pedals.mapValues { table in
            var table = table

            table.simplify(mode)

            return table
        }

        return part
    }
}
