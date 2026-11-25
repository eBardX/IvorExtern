// © 2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import IvorModel
import IvorTiming
import IvorTuning
import Testing

struct MusicXMLImporterWalkerNotesTests {
}

// MARK: -

extension MusicXMLImporterWalkerNotesTests {
    @Test
    func flushPendingTies_insertsEveryOpenTie() {
        var context = MusicXML.Importer.Context()

        context.pendingTies["1"] = ["C4": MusicXML.Importer.PendingTie(attack: beat(0),
                                                                       duration: dur(1, 2),
                                                                       extras: nil,
                                                                       ornamentation: nil)]

        MusicXML.Importer.Walker.flushPendingTies(&context)

        #expect(context.pendingTies.isEmpty)
        #expect(context.noteTables["1"]?.map(\.duration) == [dur(1, 2)])
        #expect(context.noteTables["1"]?.map(\.startPitch) == ["C4"])
    }

    @Test
    func flushPendingTies_noTies_changesNothing() {
        var context = MusicXML.Importer.Context()

        MusicXML.Importer.Walker.flushPendingTies(&context)

        #expect(context.noteTables.isEmpty)
    }

    @Test
    func insertTone_chordTone_sharesAttackAndDuration() throws {
        let notes = try walkedFirstVoiceNotes("""
            <note><pitch><step>C</step><octave>4</octave></pitch><duration>2</duration></note>
            <note><chord/><pitch><step>E</step><octave>4</octave></pitch><duration>2</duration></note>
            """)

        #expect(notes.map(\.attack) == [beat(0), beat(0)])
        #expect(notes.map(\.duration) == [dur(1, 2), dur(1, 2)])
        #expect(Set(notes.map(\.startPitch)) == ["C4", "E4"])
    }

    @Test
    func insertTone_openTie_endsWhereItWasWritten() throws {
        let notes = try walkedFirstVoiceNotes("""
            <note><pitch><step>C</step><octave>4</octave></pitch><duration>1</duration><tie type="start"/></note>
            """)

        #expect(notes.map(\.duration) == [dur(1, 4)])
    }

    @Test
    func insertTone_singleTremolo_repeatsTheNote() throws {
        let notes = try walkedFirstVoiceNotes("""
            <note>
              <pitch><step>C</step><octave>4</octave></pitch><duration>1</duration><type>quarter</type>
              <notations><ornaments><tremolo type="single">2</tremolo></ornaments></notations>
            </note>
            """)
        let strokes = try #require(TremoloStrokes(uintValue: 2))
        let ornament = notes.first?.ornamentation?.ornament

        #expect(ornament?.sign == .tremolo(.measured(strokes)))
        #expect(ornament?.partner == .repeat)
    }

    @Test
    func insertTone_tiedNotes_joinIntoOne() throws {
        let notes = try walkedFirstVoiceNotes("""
            <note><pitch><step>C</step><octave>4</octave></pitch><duration>1</duration><tie type="start"/></note>
            <note><pitch><step>C</step><octave>4</octave></pitch><duration>1</duration><tie type="stop"/></note>
            """)

        #expect(notes.count == 1)
        #expect(notes.first?.duration == dur(1, 2))
    }

    @Test
    func insertTone_twoNoteTremolo_becomesOneNoteWithAPartner() throws {
        let notes = try walkedFirstVoiceNotes("""
            <note><pitch><step>G</step><octave>4</octave></pitch><duration>1</duration></note>
            <note>
              <pitch><step>C</step><octave>4</octave></pitch><duration>1</duration><type>quarter</type>
              <notations><ornaments><tremolo type="start">2</tremolo></ornaments></notations>
            </note>
            <note>
              <pitch><step>E</step><octave>4</octave></pitch><duration>1</duration><type>quarter</type>
              <notations><ornaments><tremolo type="stop">2</tremolo></ornaments></notations>
            </note>
            """)
        let note = try #require(notes.first { $0.startPitch == "C4" })

        #expect(notes.count == 2)
        #expect(note.attack == beat(1, 4))
        #expect(note.duration == dur(1, 2))
        #expect(note.ornamentation?.ornament?.partner == .pitches(["E4"]))
    }

    @Test
    func insertTone_unclosedTwoNoteTremolo_isFlushedAsANote() throws {
        let notes = try walkedFirstVoiceNotes("""
            <note>
              <pitch><step>C</step><octave>4</octave></pitch><duration>1</duration><type>quarter</type>
              <notations><ornaments><tremolo type="start">2</tremolo></ornaments></notations>
            </note>
            <note><pitch><step>G</step><octave>4</octave></pitch><duration>1</duration></note>
            """)

        #expect(notes.map(\.startPitch).sorted() == ["C4", "G4"])
    }

    @Test
    func insertTone_unmeasuredTremolo() throws {
        let notes = try walkedFirstVoiceNotes("""
            <note>
              <pitch><step>C</step><octave>4</octave></pitch><duration>1</duration>
              <notations><ornaments><tremolo type="unmeasured">0</tremolo></ornaments></notations>
            </note>
            """)

        #expect(notes.first?.ornamentation?.ornament?.sign == .tremolo(.unmeasured))
    }
}
