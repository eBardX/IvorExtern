// © 2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import IvorModel
import IvorTiming
import IvorTuning
import Testing
import XestiTools

struct MusicXMLImporterPendingTremoloTests {
}

// MARK: -

extension MusicXMLImporterPendingTremoloTests {
    @Test
    func init_storesValues() throws {
        let strokes = try #require(TremoloStrokes(uintValue: 3))
        let pending = MusicXML.Importer.PendingTremolo(attack: beat(1, 2),
                                                       duration: dur(1, 4),
                                                       extras: channelExtras(4),
                                                       ornamentation: nil,
                                                       pitch: "G4",
                                                       strokes: strokes)

        #expect(pending.attack == beat(1, 2))
        #expect(pending.duration == dur(1, 4))
        #expect(pending.extras == channelExtras(4))
        #expect(pending.ornamentation == nil)
        #expect(pending.pitch == "G4")
        #expect(pending.strokes == strokes)
    }
}
