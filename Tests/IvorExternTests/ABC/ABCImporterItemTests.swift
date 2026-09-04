// © 2026 John Gary Pusey (see LICENSE.md)

import IvorABC
@testable import IvorExtern
import Testing

struct ABCImporterItemTests {
}

// MARK: -

extension ABCImporterItemTests {
    @Test
    func equality_field() throws {
        let length1 = try #require(ABCLength(numerator: 1, denominator: 4))
        let length2 = try #require(ABCLength(numerator: 1, denominator: 4))

        #expect(ABC.Importer.Item.field(.unitNoteLength(length1)) ==
                ABC.Importer.Item.field(.unitNoteLength(length2)))
    }

    @Test
    func equality_symbol() {
        #expect(ABC.Importer.Item.symbol(.beamBreak) == .symbol(.beamBreak))
    }

    @Test
    func inequality_differentCases() {
        #expect(ABC.Importer.Item.symbol(.beamBreak) != ABC.Importer.Item.symbol(.overlay))
    }

    @Test
    func inequality_fieldVersusSymbol() throws {
        let length = try #require(ABCLength(numerator: 1, denominator: 4))

        #expect(ABC.Importer.Item.field(.unitNoteLength(length)) != ABC.Importer.Item.symbol(.beamBreak))
    }
}
