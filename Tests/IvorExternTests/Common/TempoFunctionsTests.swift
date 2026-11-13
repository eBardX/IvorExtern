// © 2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import IvorTiming
import Testing
import XestiNumbers

struct TempoFunctionsTests {
}

// MARK: -

extension TempoFunctionsTests {
    @Test
    func plainOrDottedNoteValue_dottedValue_hasOneDot() throws {
        let result = try #require(plainOrDottedNoteValue(dur(3, 8)))

        #expect(result.base == Number(numerator: 1,
                                      denominator: 4))
        #expect(result.dots == 1)
    }

    @Test
    func plainOrDottedNoteValue_dottedWhole_hasOneDot() throws {
        let result = try #require(plainOrDottedNoteValue(dur(3, 2)))

        #expect(result.base == 1)
        #expect(result.dots == 1)
    }

    @Test
    func plainOrDottedNoteValue_doubleDottedValue_returnsNil() {
        #expect(plainOrDottedNoteValue(dur(7, 16)) == nil)
    }

    @Test
    func plainOrDottedNoteValue_longerThanWhole_hasNoDots() throws {
        let result = try #require(plainOrDottedNoteValue(dur(4)))

        #expect(result.base == 4)
        #expect(result.dots == 0)
    }

    @Test
    func plainOrDottedNoteValue_plainValue_hasNoDots() throws {
        let result = try #require(plainOrDottedNoteValue(dur(1, 4)))

        #expect(result.base == Number(numerator: 1,
                                      denominator: 4))
        #expect(result.dots == 0)
    }

    @Test
    func plainOrDottedNoteValue_tripletValue_returnsNil() {
        #expect(plainOrDottedNoteValue(dur(1, 6)) == nil)
    }

    @Test
    func plainOrDottedNoteValue_unevenValue_returnsNil() {
        #expect(plainOrDottedNoteValue(dur(5, 8)) == nil)
    }

    @Test
    func roundedTempoRate_belowOne_isOne() {
        #expect(roundedTempoRate(tempo("1/4=1/3")) == 1)
    }

    @Test
    func roundedTempoRate_fractionBelowHalf_roundsDown() {
        #expect(roundedTempoRate(tempo("1/4=66.4")) == 66)
    }

    @Test
    func roundedTempoRate_half_roundsUp() {
        #expect(roundedTempoRate(tempo("1/4=66.5")) == 67)
    }

    @Test
    func roundedTempoRate_wholeRate_isUnchanged() {
        #expect(roundedTempoRate(Tempo(120)) == 120)
    }
}
