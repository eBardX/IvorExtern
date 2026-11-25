// © 2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import IvorModel
import IvorTiming
import IvorTuning
import Testing

struct HeldTiesTests {
}

// MARK: -

extension HeldTiesTests {
    @Test
    func commit_tiedTone_waitsForItsContinuation() {
        var heldTies = HeldTies()
        var noteTable = NoteTable<BeatTime, Pitch>()

        heldTies.commit([heldTiesTone(0, "C4", isTied: true)], into: &noteTable)

        #expect(noteTable.isEmpty)

        heldTies.commit([heldTiesTone(1, "C4")], into: &noteTable)

        #expect(heldTiesSummary(noteTable) == [heldTiesEntry("C4", 0, 2)])
    }

    @Test
    func commit_tieNotContinued_endsWhereItWasWritten() {
        var heldTies = HeldTies()
        var noteTable = NoteTable<BeatTime, Pitch>()

        heldTies.commit([heldTiesTone(0, "C4", isTied: true), heldTiesTone(0, "E4", isTied: true)], into: &noteTable)
        heldTies.commit([heldTiesTone(1, "E4"), heldTiesTone(1, "G4")], into: &noteTable)

        #expect(heldTiesSummary(noteTable) == [heldTiesEntry("C4", 0, 1), heldTiesEntry("E4", 0, 2), heldTiesEntry("G4", 1, 1)])
    }

    @Test
    func commit_untiedTone_isNotContinued() {
        var heldTies = HeldTies()
        var noteTable = NoteTable<BeatTime, Pitch>()

        heldTies.commit([heldTiesTone(0, "C4"), heldTiesTone(0, "E4", isTied: true)], into: &noteTable)
        heldTies.commit([heldTiesTone(1, "C4"), heldTiesTone(1, "E4")], into: &noteTable)

        #expect(heldTiesSummary(noteTable) == [heldTiesEntry("C4", 0, 1), heldTiesEntry("C4", 1, 1), heldTiesEntry("E4", 0, 2)])
    }

    @Test
    func end_insertsEveryHeldTie() {
        var heldTies = HeldTies()
        var noteTable = NoteTable<BeatTime, Pitch>()

        heldTies.commit([heldTiesTone(0, "C4", isTied: true)], into: &noteTable)
        heldTies.end(in: &noteTable)

        #expect(heldTiesSummary(noteTable) == [heldTiesEntry("C4", 0, 1)])

        heldTies.end(in: &noteTable)

        #expect(noteTable.count == 1)
    }
}
