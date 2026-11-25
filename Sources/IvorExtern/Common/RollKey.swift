// © 2026 John Gary Pusey (see LICENSE.md)

internal import IvorModel
internal import IvorTiming
internal import IvorTuning

//
// What makes tones one rolled chord: their attack and their arpeggio group, anywhere in the work
// (resolution 13 of the grace-notes plan).
//
internal struct RollKey {

    // MARK: Internal Instance Properties

    internal let attack: BeatTime
    internal let group: ArpeggioGroup
}

// MARK: -

extension RollKey {

    // MARK: Internal Type Methods

    //
    // The rolls whose tones are in more than one part, each with the first part it's in: the
    // notation formats roll a chord within one part only, so each part writes its own.
    //
    internal static func sharedRolls(_ parts: [Part<BeatTime, Pitch>]) -> [Self: Int] {
        var partsByRoll: [Self: Set<Int>] = [:]

        for (index, part) in parts.enumerated() {
            for note in part.noteTable {
                if let arpeggio = note.ornamentation?.arpeggio {
                    partsByRoll[Self(attack: note.attack, group: arpeggio.group), default: []].insert(index)
                }
            }
        }

        return partsByRoll.filter { $0.value.count > 1 }.compactMapValues { $0.min() }
    }
}

// MARK: - Hashable

extension RollKey: Hashable {
}

// MARK: - Sendable

extension RollKey: Sendable {
}
