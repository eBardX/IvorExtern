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
//
// A pedal in `hidden` is written as `<sound>` attributes alone too, with no
// marks: every change as its level, and a re-pedal as two directions at one
// time, up and then the new level. `MusicXML.Exporter` hides a pedal that an
// earlier part already shows the same way (see `repeatedPedals(_:)`), so
// that voices split from one MusicXML part don't repeat its marks, while
// each part still carries the pedal it plays with.
internal func makeMusicXMLPedalDirections(_ pedals: [Pedal: PedalTable<BeatTime>],
                                          hidden: Set<Pedal> = []) -> [(BeatTime, MXLDirection)] {
    var directions: [(BeatTime, MXLDirection, Int)] = []

    for (order, pedal) in [Pedal.sustain, .sostenuto, .soft].enumerated() {
        guard let table = pedals[pedal]
        else { continue }

        let isHidden = pedal == .soft || hidden.contains(pedal)
        var previous: Pedal.Level = .up

        for (time, levels) in groupedByTime(table) {
            guard let final = levels.last
            else { continue }

            if isHidden {
                for level in _hiddenLevels(after: previous, levels) {
                    directions.append((time, _makeSoundDirection(pedal, level), order))
                }
            } else {
                let marks = _pedalMarks(pedal,
                                        before: previous,
                                        levels: levels)
                let writesSound = final != previous && (_isPartial(final) || _isPartial(previous))

                if !marks.isEmpty || writesSound {
                    let sound = writesSound ? _makeSound(pedal, final) : nil
                    let kinds = marks.isEmpty
                        ? [emptyWordsKind]
                        : marks.map { MXLDirection.Kind(content: .pedal($0)) }

                    directions.append((time, MXLDirection(kind: kinds, sound: sound), order))
                }
            }

            previous = final
        }
    }

    return directions
        .enumerated()
        .sorted { ($0.element.0, $0.element.2, $0.offset) < ($1.element.0, $1.element.2, $1.offset) }
        .map { ($0.element.0, $0.element.1) }
}

// For each of `pedalsByPart`, the pedals that `makeMusicXMLPedalDirections`
// should hide: the sustain and sostenuto tables identical (in their times and
// levels) to the same pedal's table in an earlier part, whose marks show
// already. Voices split from one MusicXML part on import all carry that
// part's tables, and this is how their export tells them apart. Two unrelated
// parts pedalled alike are hidden too, which costs only the later part's
// marks: its pedal still plays, and re-imports, from the `<sound>` values.
internal func repeatedPedals(_ pedalsByPart: [[Pedal: PedalTable<BeatTime>]]) -> [Set<Pedal>] {
    pedalsByPart.indices.map { index in
        Set([Pedal.sustain, .sostenuto].filter { pedal in
            guard let table = pedalsByPart[index][pedal]
            else { return false }

            return pedalsByPart[..<index].contains { earlier in
                earlier[pedal].map { _hasSameEntries($0, table) } ?? false
            }
        })
    }
}

// MARK: Private Constants

//
// A `<direction>` needs a `<direction-type>`; an empty `<words>` is the
// conventional invisible one for a direction that only carries `<sound>`.
//
private let emptyWordsKind = MXLDirection.Kind(content: .words(MXLFormattedTextID(value: "")))

// MARK: Private Functions

private func _hasSameEntries(_ lhs: PedalTable<BeatTime>,
                             _ rhs: PedalTable<BeatTime>) -> Bool {
    lhs.count == rhs.count
        && zip(lhs, rhs).allSatisfy { $0.time == $1.time && $0.level == $1.level }
}

// The levels a hidden pedal writes for one time's entries, given the level
// before them: up and then the new level for a re-pedal (see
// `pedalSwitches(after:_:)`), the new level alone for any other change, and
// nothing if the level stays the same.
private func _hiddenLevels(after previous: Pedal.Level,
                           _ levels: [Pedal.Level]) -> [Pedal.Level] {
    guard let final = levels.last
    else { return [] }

    if pedalSwitches(after: previous, levels) == [false, true] {
        return [.up, final]
    }

    return final != previous ? [final] : []
}

private func _isPartial(_ level: Pedal.Level) -> Bool {
    level != .up && level != .down
}

private func _makeSound(_ pedal: Pedal,
                        _ level: Pedal.Level) -> MXLSound {
    let value: MXLYesNoNumber = switch level {
    case .up:
        .no

    case .down:
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

private func _makeSoundDirection(_ pedal: Pedal,
                                 _ level: Pedal.Level) -> MXLDirection {
    MXLDirection(kind: [emptyWordsKind],
                 sound: _makeSound(pedal, level))
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
