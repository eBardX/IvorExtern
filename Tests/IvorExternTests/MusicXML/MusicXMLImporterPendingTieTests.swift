// © 2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import IvorModel
import IvorTiming
import IvorTuning
import Testing

struct MusicXMLImporterPendingTieTests {
}

// MARK: -

extension MusicXMLImporterPendingTieTests {
    @Test
    func init_storesValues() throws {
        let pending = try MusicXML.Importer.PendingTie(attack: beat(1),
                                                       duration: dur(1, 2),
                                                       extras: nil,
                                                       ornamentation: .init(graceBefore: graceFigure("D4")))

        #expect(pending.attack == beat(1))
        #expect(pending.duration == dur(1, 2))
        #expect(pending.extras == nil)
        #expect(pending.ornamentation?.graceBefore != nil)
    }

    @Test
    func mutation_gathersDuration() {
        var pending = MusicXML.Importer.PendingTie(attack: .zero,
                                                   duration: dur(1, 4),
                                                   extras: nil,
                                                   ornamentation: nil)

        pending.duration += dur(1, 4)

        #expect(pending.duration == dur(1, 2))
    }
}
