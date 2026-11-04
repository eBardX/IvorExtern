// © 2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import IvorModel
import IvorTiming
import IvorTuning
import Testing

struct PartFunctionsTests {
}

// MARK: -

extension PartFunctionsTests {
    @Test
    func fillEmptyPartNames_duplicateRealNames_leavesThemAlone() {
        let parts = [emptyPart("Violin"), emptyPart("Violin")]

        #expect(fillEmptyPartNames(parts).map(\.name) == ["Violin", "Violin"])
    }

    @Test
    func fillEmptyPartNames_mixedNamedAndUnnamed_fillsOnlyUnnamed() {
        let parts = [emptyPart("Flute"), emptyPart(""), emptyPart("Oboe"), emptyPart("")]

        #expect(fillEmptyPartNames(parts).map(\.name) == ["Flute", "Voice 2", "Oboe", "Voice 4"])
    }

    @Test
    func fillEmptyPartNames_multiplePartsAllUnnamed_namesEachByPosition() {
        let parts = [emptyPart(""), emptyPart(""), emptyPart("")]

        #expect(fillEmptyPartNames(parts).map(\.name) == ["Voice 1", "Voice 2", "Voice 3"])
    }

    @Test
    func fillEmptyPartNames_noParts_returnsEmpty() {
        #expect(fillEmptyPartNames([Part<BeatTime, Pitch>]()).isEmpty)
    }

    @Test
    func fillEmptyPartNames_singleUnnamedPart_leavesItUnnamed() {
        #expect(fillEmptyPartNames([emptyPart("")]).map(\.name) == [""])
    }

    @Test
    func isFallbackPartName_lonePart_isFalse() {
        #expect(!isFallbackPartName("Voice 1", index: 0, count: 1))
    }

    @Test
    func isFallbackPartName_matchingPositionInMultiPartWork_isTrue() {
        #expect(isFallbackPartName("Voice 2", index: 1, count: 3))
    }

    @Test
    func isFallbackPartName_otherPosition_isFalse() {
        #expect(!isFallbackPartName("Voice 2", index: 2, count: 3))
    }

    @Test
    func normalizeName_collapsesWhitespaceAndControlCharacters() {
        #expect(normalizeName("  Violin\n I\t\u{0}\u{0}") == "Violin I")
    }

    @Test
    func normalizeName_whitespaceOnly_returnsEmpty() {
        #expect(normalizeName(" \n\t ").isEmpty)
    }
}
