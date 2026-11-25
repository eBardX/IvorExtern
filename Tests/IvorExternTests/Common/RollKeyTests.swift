// © 2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import IvorModel
import IvorTiming
import IvorTuning
import Testing
import XestiNumbers
import XestiTools

struct RollKeyTests {
}

// MARK: -

extension RollKeyTests {
    @Test
    func sharedRolls_givesEachRollInSeveralPartsItsFirstPart() throws {
        var upper = Part<BeatTime, Pitch>(name: "Upper")
        var lower = Part<BeatTime, Pitch>(name: "Lower")
        let shared = BeatNotes.Ornamentation(arpeggio: BeatNotes.Arpeggio(group: 1))
        let own = BeatNotes.Ornamentation(arpeggio: BeatNotes.Arpeggio(group: 2))

        try upper.noteTable.insert(attack: 0, duration: dur(1, 4), pitch: .c5, ornamentation: shared)
        try lower.noteTable.insert(attack: 0, duration: dur(1, 4), pitch: .c4, ornamentation: shared)
        try lower.noteTable.insert(attack: beat(1, 4), duration: dur(1, 4), pitch: .e4, ornamentation: own)
        try lower.noteTable.insert(attack: beat(1, 4), duration: dur(1, 4), pitch: .g4, ornamentation: own)

        #expect(RollKey.sharedRolls([upper, lower]) == [RollKey(attack: 0, group: 1): 0])
    }

    @Test
    func sharedRolls_sameGroupAtAnotherAttack_isAnotherRoll() throws {
        var upper = Part<BeatTime, Pitch>(name: "Upper")
        var lower = Part<BeatTime, Pitch>(name: "Lower")
        let roll = BeatNotes.Ornamentation(arpeggio: BeatNotes.Arpeggio(group: 1))

        try upper.noteTable.insert(attack: 0, duration: dur(1, 4), pitch: .c5, ornamentation: roll)
        try lower.noteTable.insert(attack: beat(1, 4), duration: dur(1, 4), pitch: .c4, ornamentation: roll)

        #expect(RollKey.sharedRolls([upper, lower]).isEmpty)
    }
}
