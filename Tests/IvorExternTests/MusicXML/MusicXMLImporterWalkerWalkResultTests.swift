// © 2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import IvorModel
import IvorMXL
import IvorTiming
import IvorTuning
import Testing

struct MusicXMLImporterWalkerWalkResultTests {
}

// MARK: -

extension MusicXMLImporterWalkerWalkResultTests {
    @Test
    func init_storesProperties() throws {
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

        let result = try MusicXML.Importer.Walker.WalkResult(barlines: [(beatTime: .zero, meter: .free, extras: nil)],
                                                             directionDynamicEvents: [dynamicEvent],
                                                             keyEvents: [(beatTime: .zero, key: key(2, .major))],
                                                             panEvents: [(beatTime: .zero, pan: .center)],
                                                             part: part,
                                                             pedalEvents: [(beatTime: .zero, pedal: .sustain, level: .down)],
                                                             tempoEvents: [(beatTime: .zero, tempo: .default)],
                                                             warningCounts: [.droppedNonArpeggiate: 1])

        #expect(result.barlines.map(\.meter) == [.free])
        #expect(result.directionDynamicEvents.map(\.kind) == [.step])
        #expect(try result.keyEvents.map(\.key) == [key(2, .major)])
        #expect(result.panEvents.map(\.pan) == [.center])
        #expect(result.part.part == scorePart)
        #expect(result.pedalEvents.map(\.pedal) == [.sustain])
        #expect(result.tempoEvents.map(\.tempo) == [.default])
        #expect(result.warningCounts == [.droppedNonArpeggiate: 1])
    }
}
