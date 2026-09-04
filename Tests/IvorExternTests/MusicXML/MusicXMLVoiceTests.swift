// © 2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import IvorModel
import IvorTiming
import IvorTuning
import Testing
import XestiNumbers

struct MusicXMLVoiceTests {
}

// MARK: -

extension MusicXMLVoiceTests {
    @Test
    func init_nilID_forImplicitVoice() {
        let voice = MusicXML.Voice(id: nil,
                                   noteTable: NoteTable<BeatTime, Pitch>())

        #expect(voice.id == nil)
    }

    @Test
    func init_storesIDAndNoteTable() {
        var noteTable = NoteTable<BeatTime, Pitch>()

        noteTable.insert(attack: .zero,
                         duration: BeatDuration(1),
                         pitch: "C4")

        let voice = MusicXML.Voice(id: "1",
                                   noteTable: noteTable)

        #expect(voice.id == "1")
        #expect(!voice.noteTable.isEmpty)
    }
}
