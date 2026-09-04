// © 2025–2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import Testing
import XestiNumbers

struct GuidoDurationTests {
}

// MARK: -

extension GuidoDurationTests {
    @Test
    func equality() {
        let duration1 = Guido.Duration(numberValue: Number(numerator: 1, denominator: 4))
        let duration2 = Guido.Duration(numberValue: Number(numerator: 1, denominator: 4))

        #expect(duration1 == duration2)
    }

    @Test
    func inequality() {
        let duration1 = Guido.Duration(numberValue: Number(numerator: 1, denominator: 4))
        let duration2 = Guido.Duration(numberValue: Number(numerator: 1, denominator: 2))

        #expect(duration1 != duration2)
    }

    @Test
    func init_storesNumberValue() {
        let number = Number(numerator: 3, denominator: 8)

        let duration = Guido.Duration(numberValue: number)

        #expect(duration.numberValue == number)
    }
}
