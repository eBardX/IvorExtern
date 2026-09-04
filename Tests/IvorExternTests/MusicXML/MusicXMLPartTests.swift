// © 2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import IvorModel
import IvorMusicXML
import IvorTiming
import IvorTuning
import Testing

struct MusicXMLPartTests {
}

// MARK: -

extension MusicXMLPartTests {
    @Test
    func init_storesPartAndVoices() {
        let scorePart = MXLScorePart(id: "P1",
                                     name: MXLPartName(value: "Violin",
                                                       text: .init()))
        let voice = MusicXML.Voice(id: "1",
                                   noteTable: NoteTable<BeatTime, Pitch>())

        let part = MusicXML.Part(part: scorePart,
                                 voices: [voice])

        #expect(part.part == scorePart)
        #expect(part.voices.map(\.id) == ["1"])
    }

    @Test
    func init_withNoVoices() {
        let scorePart = MXLScorePart(id: "P1",
                                     name: MXLPartName(value: "Violin",
                                                       text: .init()))

        let part = MusicXML.Part(part: scorePart,
                                 voices: [])

        #expect(part.voices.isEmpty)
    }
}
