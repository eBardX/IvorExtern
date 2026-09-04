// © 2025–2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import Testing
import XestiNumbers

struct GuidoRestTests {
}

// MARK: -

extension GuidoRestTests {
    @Test
    func equality() {
        let duration = Guido.Duration(numberValue: Number(numerator: 1, denominator: 4))

        let rest1 = Guido.Rest(duration: duration)
        let rest2 = Guido.Rest(duration: duration)

        #expect(rest1 == rest2)
    }

    @Test
    func inequality() {
        let rest1 = Guido.Rest(duration: Guido.Duration(numberValue: Number(numerator: 1, denominator: 4)))
        let rest2 = Guido.Rest(duration: Guido.Duration(numberValue: Number(numerator: 1, denominator: 2)))

        #expect(rest1 != rest2)
    }

    @Test
    func init_storesDuration() {
        let duration = Guido.Duration(numberValue: Number(numerator: 3, denominator: 8))

        let rest = Guido.Rest(duration: duration)

        #expect(rest.duration == duration)
    }
}
