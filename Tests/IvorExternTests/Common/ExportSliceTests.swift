// © 2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import IvorModel
import IvorTiming
import IvorTuning
import Testing

struct ExportSliceTests {
}

// MARK: -

extension ExportSliceTests {
    @Test
    func slices_chordOfEqualTones_isOneUntiedSlice() {
        let slices = exportSlices([(0, 1, "C4"), (0, 1, "E4")], at: [0, 1])

        #expect(slices.count == 1)
        #expect(Set(exportTonePitches(slices[0].tones)) == ["C4", "E4"])
        #expect(Set(exportTonePitches(slices[0].attackedTones)) == ["C4", "E4"])
        #expect(Set(exportTonePitches(slices[0].releasedTones)) == ["C4", "E4"])
        #expect(!slices[0].isWhollyTied)
    }

    @Test
    func slices_emptyStretch_hasNoTones() {
        let slices = exportSlices([(0, 1, "C4"), (2, 1, "E4")], at: [0, 1, 2, 3])

        #expect(slices.map { exportTonePitches($0.tones) } == [["C4"], [], ["E4"]])
    }

    @Test
    func slices_heldTone_isTiedIntoEachLaterSlice() {
        let slices = exportSlices([(0, 3, "C4"), (1, 2, "E4"), (2, 2, "G4")], at: [0, 1, 2, 3, 4])

        #expect(slices.map { exportTonePitches($0.tones) } == [["C4"], ["C4", "E4"], ["C4", "E4", "G4"], ["G4"]])
        #expect(slices.map { exportTonePitches($0.attackedTones) } == [["C4"], ["E4"], ["G4"], []])
        #expect(slices.map { exportTonePitches($0.releasedTones) } == [[], [], ["C4", "E4"], ["G4"]])
        #expect(slices.map(\.isWhollyTied) == [true, true, false, false])
        #expect(slices[2].tones.map(slices[2].isTiedIn) == [true, true, false])
        #expect(slices[2].tones.map(slices[2].continues) == [false, false, true])
    }

    @Test
    func slices_tonesKeepTableOrder() {
        let slices = exportSlices([(0, 2, "G4"), (0, 1, "C4"), (1, 1, "E4")], at: [0, 1, 2])

        #expect(slices.map { exportTonePitches($0.tones) } == [["C4", "G4"], ["G4", "E4"]])
    }

    @Test
    func tones_areInAttackOrder() {
        var noteTable = NoteTable<BeatTime, Pitch>()

        noteTable.insert(attack: beat(1), duration: dur(1), pitch: "E4")
        noteTable.insert(attack: .zero, duration: dur(1), pitch: "C4")

        let tones = ExportTone.tones(of: noteTable)

        #expect(exportTonePitches(tones) == ["C4", "E4"])
        #expect(tones.map(\.index) == [0, 1])
        #expect(tones.map(\.end) == [beat(1), beat(2)])
    }
}
