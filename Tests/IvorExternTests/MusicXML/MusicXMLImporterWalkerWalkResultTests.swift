// © 2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import IvorModel
import IvorMusicXML
import IvorTiming
import IvorTuning
import Testing

struct MusicXMLImporterWalkerWalkResultTests {
}

// MARK: -

extension MusicXMLImporterWalkerWalkResultTests {
    @Test
    func init_storesProperties() {
        let scorePart = MXLScorePart(id: "P1",
                                     name: MXLPartName(value: "Violin",
                                                       text: .init()))
        let voice = MusicXML.Voice(id: "1",
                                   noteTable: NoteTable<BeatTime, Pitch>())
        let part = MusicXML.Part(part: scorePart,
                                 voices: [voice])
        let dynamicEvent = MusicXML.Importer.Context.DynamicEvent(beatTime: .zero,
                                                                  dynamic: .mf,
                                                                  kind: .step)

        let result = MusicXML.Importer.Walker.WalkResult(directionDynamicEvents: [dynamicEvent],
                                                         panEvents: [(beatTime: .zero, pan: .center)],
                                                         part: part,
                                                         tempoEvents: [(beatTime: .zero, tempo: .default)])

        #expect(result.directionDynamicEvents.map(\.kind) == [.step])
        #expect(result.panEvents.map(\.pan) == [.center])
        #expect(result.part.part == scorePart)
        #expect(result.tempoEvents.map(\.tempo) == [.default])
    }
}
