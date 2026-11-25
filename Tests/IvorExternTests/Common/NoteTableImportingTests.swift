// © 2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import IvorModel
import IvorTiming
import IvorTuning
import Testing

struct NoteTableImportingTests {
}

// MARK: -

extension NoteTableImportingTests {
    @Test
    func insertImported_noOrnamentation() {
        var noteTable = NoteTable<BeatTime, Pitch>()

        noteTable.insertImported(attack: beat(0),
                                 duration: dur(1),
                                 pitch: "C4",
                                 extras: nil,
                                 ornamentation: nil)

        #expect(noteTable.count == 1)
        #expect(noteTable.first?.ornamentation == nil)
    }

    @Test
    func insertImported_partnerOnWrongSide_keepsTheRest() throws {
        var noteTable = NoteTable<BeatTime, Pitch>()
        let event = try #require(BeatNotes.GraceFigure.Event(pitches: ["D4"]))
        let figure = try #require(BeatNotes.GraceFigure(events: [event]))
        let trill = try #require(BeatNotes.Ornament(sign: .trill, partner: .step(.above, written: "A3")))

        noteTable.insertImported(attack: beat(0),
                                 duration: dur(1),
                                 pitch: "C4",
                                 extras: nil,
                                 ornamentation: .init(graceBefore: figure, ornament: trill))

        let ornamentation = noteTable.first?.ornamentation

        #expect(noteTable.count == 1)
        #expect(ornamentation?.ornament == nil)
        #expect(ornamentation?.graceBefore == figure)
    }

    @Test
    func insertImported_partnerOnWrongSide_onlyOrnament_dropsOrnamentation() throws {
        var noteTable = NoteTable<BeatTime, Pitch>()
        let trill = try #require(BeatNotes.Ornament(sign: .trill, partner: .step(.above, written: "A3")))

        noteTable.insertImported(attack: beat(0),
                                 duration: dur(1),
                                 pitch: "C4",
                                 extras: channelExtras(1),
                                 ornamentation: .init(ornament: trill))

        #expect(noteTable.count == 1)
        #expect(noteTable.first?.ornamentation == nil)
        #expect(noteTable.first?.extras == channelExtras(1))
    }

    @Test
    func insertImported_validOrnament_isKept() throws {
        var noteTable = NoteTable<BeatTime, Pitch>()
        let trill = try #require(BeatNotes.Ornament(sign: .trill, partner: .step(.above, written: "D4")))

        let noteID = noteTable.insertImported(attack: beat(0),
                                              duration: dur(1),
                                              pitch: "C4",
                                              extras: nil,
                                              ornamentation: .init(ornament: trill))

        let note = try #require(noteTable.first)

        #expect(note.noteID == noteID)
        #expect(note.ornamentation?.ornament == trill)
    }
}
