// © 2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import IvorGMN
import IvorModel
import IvorTiming
import Testing
import XestiNumbers
import XestiTools

struct GuidoImporterPendingNoteTests {
}

// MARK: -

extension GuidoImporterPendingNoteTests {
    @Test
    func init_storesValues() throws {
        let octave = try #require(GMNPitch.Octave(intValue: 1))
        let note = Guido.Note(duration: Guido.Duration(numberValue: Number(numerator: 1, denominator: 4)),
                              pitch: Guido.Pitch(accidental: .natural, name: .c, octave: octave))
        let pending = Guido.Importer.PendingNote(attackTime: beat(1, 4),
                                                 extras: channelExtras(1).elements,
                                                 notes: [note],
                                                 ornaments: Guido.Importer.Ornaments())

        #expect(pending.attackTime == beat(1, 4))
        #expect(pending.extras == channelExtras(1).elements)
        #expect(pending.notes == [note])
        #expect(pending.ornaments.isEmpty)
    }

    @Test
    func mutation_updatesValues() {
        var pending = Guido.Importer.PendingNote(attackTime: .zero,
                                                 extras: [],
                                                 notes: [],
                                                 ornaments: Guido.Importer.Ornaments())

        pending.attackTime = beat(1)
        pending.ornaments.fermata = .normal

        #expect(pending.attackTime == beat(1))
        #expect(!pending.ornaments.isEmpty)
    }
}
