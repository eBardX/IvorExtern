// © 2026 John Gary Pusey (see LICENSE.md)

import IvorABC
@testable import IvorExtern
import Testing
import XestiNumbers

struct ABCDurationTests {
}

// MARK: -

extension ABCDurationTests {
    @Test
    func addition() {
        let lhs = ABC.Duration(numberValue: Number(numerator: 1, denominator: 4))
        let rhs = ABC.Duration(numberValue: Number(numerator: 1, denominator: 4))

        let sum = lhs + rhs

        #expect(sum == ABC.Duration(numberValue: Number(numerator: 1, denominator: 2)))
    }

    @Test
    func equality() {
        let lhs = ABC.Duration(numberValue: Number(numerator: 1, denominator: 4))
        let rhs = ABC.Duration(numberValue: Number(numerator: 2, denominator: 8))

        #expect(lhs == rhs)
    }

    @Test
    func inequality() {
        let lhs = ABC.Duration(numberValue: Number(numerator: 1, denominator: 4))
        let rhs = ABC.Duration(numberValue: Number(numerator: 1, denominator: 2))

        #expect(lhs != rhs)
    }

    @Test
    func init_length() throws {
        let length = try #require(ABCLength(numerator: 3, denominator: 8))

        let duration = ABC.Duration(length: length)

        #expect(duration == ABC.Duration(numberValue: Number(numerator: 3, denominator: 8)))
    }

    @Test
    func init_numberValue() {
        let numberValue = Number(numerator: 1, denominator: 4)

        let duration = ABC.Duration(numberValue: numberValue)

        #expect(duration.numberValue == numberValue)
    }

    @Test
    func init_written_unitNoteLength() throws {
        let written = try #require(ABCLength(numerator: 2, denominator: 1))

        let duration = ABC.Duration(written: written, unitNoteLength: (1, 8))

        // written 2/1 × unit note length 1/8 = 2/8 = 1/4.
        #expect(duration == ABC.Duration(numberValue: Number(numerator: 1, denominator: 4)))
    }

    @Test
    func multiplication() {
        let duration = ABC.Duration(numberValue: Number(numerator: 1, denominator: 4))

        let scaled = duration * (numerator: 3, denominator: 2)

        #expect(scaled == ABC.Duration(numberValue: Number(numerator: 3, denominator: 8)))
    }
}
