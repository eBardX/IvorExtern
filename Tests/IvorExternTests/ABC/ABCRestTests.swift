// © 2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import Testing
import XestiNumbers

struct ABCRestTests {
}

// MARK: -

extension ABCRestTests {
    @Test
    func equality() {
        let duration1 = ABC.Duration(numberValue: Number(numerator: 1, denominator: 4))
        let duration2 = ABC.Duration(numberValue: Number(numerator: 1, denominator: 4))

        #expect(ABC.Rest(duration: duration1) == ABC.Rest(duration: duration2))
    }

    @Test
    func inequality() {
        let duration1 = ABC.Duration(numberValue: Number(numerator: 1, denominator: 4))
        let duration2 = ABC.Duration(numberValue: Number(numerator: 1, denominator: 2))

        #expect(ABC.Rest(duration: duration1) != ABC.Rest(duration: duration2))
    }

    @Test
    func init_storesDuration() {
        let duration = ABC.Duration(numberValue: Number(numerator: 1, denominator: 4))

        let rest = ABC.Rest(duration: duration)

        #expect(rest.duration == duration)
    }
}
