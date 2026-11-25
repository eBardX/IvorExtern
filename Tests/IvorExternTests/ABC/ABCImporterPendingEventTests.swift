// © 2026 John Gary Pusey (see LICENSE.md)

import IvorABC
@testable import IvorExtern
import IvorModel
import IvorTiming
import Testing
import XestiNumbers
import XestiTools

struct ABCImporterPendingEventTests {
}

// MARK: -

extension ABCImporterPendingEventTests {
    @Test
    func init_storesValues() {
        let rest = ABC.Rest(duration: ABC.Duration(numberValue: Number(numerator: 1, denominator: 4)))
        let pending = ABC.Importer.PendingEvent(attack: beat(1, 2),
                                                event: .rest(rest),
                                                extras: channelExtras(2).elements,
                                                ornaments: ABC.Importer.Ornaments())

        #expect(pending.attack == beat(1, 2))
        #expect(pending.event == .rest(rest))
        #expect(pending.extras == channelExtras(2).elements)
        #expect(pending.ornaments.isEmpty)
    }

    @Test
    func mutation_updatesValues() {
        let rest = ABC.Rest(duration: ABC.Duration(numberValue: Number(numerator: 1, denominator: 4)))
        var pending = ABC.Importer.PendingEvent(attack: .zero,
                                                event: .rest(rest),
                                                extras: [],
                                                ornaments: ABC.Importer.Ornaments())

        pending.attack = beat(1)
        pending.ornaments.fermata = true

        #expect(pending.attack == beat(1))
        #expect(!pending.ornaments.isEmpty)
    }
}
