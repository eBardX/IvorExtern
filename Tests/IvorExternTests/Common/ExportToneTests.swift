// © 2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import IvorModel
import IvorTiming
import IvorTuning
import Testing

struct ExportToneTests {
}

// MARK: -

extension ExportToneTests {
    @Test
    func end_isAttackPlusDuration() {
        var noteTable = NoteTable<BeatTime, Pitch>()

        noteTable.insert(attack: beat(1, 4), duration: dur(1, 2), pitch: "C4")

        #expect(ExportTone.tones(of: noteTable).first?.end == beat(3, 4))
    }

    @Test
    func tones_emptyTable() {
        #expect(ExportTone.tones(of: NoteTable<BeatTime, Pitch>()).isEmpty)
    }

    @Test
    func tones_inAttackOrder_withIndices() {
        var noteTable = NoteTable<BeatTime, Pitch>()

        noteTable.insert(attack: beat(1), duration: dur(1), pitch: "E4")
        noteTable.insert(attack: beat(0), duration: dur(1), pitch: "C4")

        let tones = ExportTone.tones(of: noteTable)

        #expect(tones.map(\.pitch) == ["C4", "E4"])
        #expect(tones.map(\.index) == [0, 1])
        #expect(tones.map(\.attack) == [beat(0), beat(1)])
    }

    @Test
    func tones_keepsExtrasAndOrnamentation() throws {
        var noteTable = NoteTable<BeatTime, Pitch>()
        let trill = try #require(BeatNotes.Ornament(sign: .trill, partner: .step(.above, written: nil)))

        try noteTable.insert(attack: beat(0),
                             duration: dur(1),
                             pitch: "C4",
                             extras: channelExtras(3),
                             ornamentation: .init(ornament: trill))

        let tone = try #require(ExportTone.tones(of: noteTable).first)

        #expect(tone.extras == channelExtras(3))
        #expect(tone.ornamentation?.ornament == trill)
    }

    @Test
    func tones_sameAttack_keepTableOrder() {
        var noteTable = NoteTable<BeatTime, Pitch>()

        noteTable.insert(attack: beat(0), duration: dur(1), pitch: "G4")
        noteTable.insert(attack: beat(0), duration: dur(1), pitch: "C4")

        let tones = ExportTone.tones(of: noteTable)
        let expected = noteTable.map(\.startPitch)

        #expect(tones.map(\.pitch) == expected)
        #expect(tones.map(\.index) == [0, 1])
    }
}
