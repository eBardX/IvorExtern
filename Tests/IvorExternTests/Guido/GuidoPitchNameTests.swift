// © 2025–2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import Testing

struct GuidoPitchNameTests {
}

// MARK: -

extension GuidoPitchNameTests {
    @Test
    func equality() {
        #expect(Guido.Pitch.Name.g == .g)
    }

    @Test
    func inequality_allCasesDistinct() {
        let cases: [Guido.Pitch.Name] = [.a, .b, .c, .d, .e, .empty, .f, .g]

        for (index, lhs) in cases.enumerated() {
            for (otherIndex, rhs) in cases.enumerated() where index != otherIndex {
                #expect(lhs != rhs)
            }
        }
    }
}
