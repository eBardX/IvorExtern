// © 2026 John Gary Pusey (see LICENSE.md)

internal import IvorModel
internal import IvorMXL
internal import IvorTiming

private import XestiNumbers

// MARK: Internal Functions

// The `<direction>`s that write a part's pedals, in time order, at most one
// per pedal per time. Sustain and sostenuto become `<pedal>` marks,
// thresholded at `Pedal.Level.isDown`: `start` (or `sostenuto`) where the
// pedal goes down, `stop` where it comes up, and `change` where it comes up
// and goes down again at one time. The sostenuto pedal's marks carry
// `number="2"` so that a `stop` closes the right pedal when the two overlap.
// A level that is neither all the way up nor down — or a return to one
// from such a level — also writes the exact level as the direction's
// `<sound>` attribute, in percent, so half-pedaling isn't lost; an importer
// takes that over the mark. The soft pedal has no mark, so it is written as
// `<sound soft-pedal>` alone. Legato and portamento have no MusicXML form
// and are dropped.
internal func makeMusicXMLPedalDirections(_ pedals: [Pedal: PedalTable<BeatTime>]) -> [(BeatTime, MXLDirection)] {
    var directions: [(BeatTime, MXLDirection, Int)] = []

    for (order, pedal) in [Pedal.sustain, .sostenuto, .soft].enumerated() {
        guard let table = pedals[pedal]
        else { continue }

        var previous: Pedal.Level = .off

        for (time, levels) in groupedByTime(table) {
            guard let final = levels.last
            else { continue }

            let marks = pedal == .soft ? [] : _pedalMarks(pedal,
                                                          before: previous,
                                                          levels: levels)
            let writesSound = final != previous && (pedal == .soft || _isPartial(final) || _isPartial(previous))

            if !marks.isEmpty || writesSound {
                let sound = writesSound ? _makeSound(pedal, final) : nil
                let kinds = marks.isEmpty
                    ? [MXLDirection.Kind(content: .words(MXLFormattedTextID(value: "")))]
                    : marks.map { MXLDirection.Kind(content: .pedal($0)) }

                directions.append((time, MXLDirection(kind: kinds, sound: sound), order))
            }

            previous = final
        }
    }

    return directions
        .sorted { ($0.0, $0.2) < ($1.0, $1.2) }
        .map { ($0.0, $0.1) }
}

// MARK: Private Functions

private func _isPartial(_ level: Pedal.Level) -> Bool {
    level != .off && level != .on
}

private func _makeSound(_ pedal: Pedal,
                        _ level: Pedal.Level) -> MXLSound {
    let value: MXLYesNoNumber = switch level {
    case .off:
        .no

    case .on:
        .yes

    default:
        .number(level.doubleValue * 100)
    }

    switch pedal {
    case .soft:
        return MXLSound(softPedal: value)

    case .sostenuto:
        return MXLSound(sostenutoPedal: value)

    default:
        return MXLSound(damperPedal: value)
    }
}

// The marks for one time's entries, given the level before them (see
// `pedalSwitches(after:_:)`): a press is `start` (`sostenuto` for that
// pedal), a release `stop`, and a re-pedal `change`.
private func _pedalMarks(_ pedal: Pedal,
                         before previous: Pedal.Level,
                         levels: [Pedal.Level]) -> [MXLPedal] {
    let number = pedal == .sostenuto ? MXLNumberLevel(uintValue: 2) : nil
    let kind: MXLPedal.Kind

    switch pedalSwitches(after: previous, levels) {
    case [false]:
        kind = .stop

    case [false, true]:
        kind = .change

    case [true]:
        kind = pedal == .sostenuto ? .sostenuto : .start

    default:
        return []
    }

    return [MXLPedal(kind: kind, number: number)]
}
