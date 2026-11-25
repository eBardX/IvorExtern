// © 2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import IvorModel
import IvorTiming
import IvorTuning
import Testing

struct MusicXMLImporterToneRefTests {
}

// MARK: -

extension MusicXMLImporterToneRefTests {
    @Test
    func inserted_carriesItsNoteID() {
        var noteTable = NoteTable<BeatTime, Pitch>()
        let noteID = noteTable.insert(attack: .zero, duration: dur(1), pitch: "C4")
        let ref = MusicXML.Importer.ToneRef.inserted(noteID)

        guard case let .inserted(carried) = ref
        else { Issue.record("Expected an inserted tone"); return }

        #expect(carried == noteID)
    }

    @Test
    func pending_carriesItsPitch() {
        let ref = MusicXML.Importer.ToneRef.pending("E4")

        guard case let .pending(pitch) = ref
        else { Issue.record("Expected a pending tone"); return }

        #expect(pitch == "E4")
    }
}
