// © 2025–2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import Testing

struct GuidoPitchAccidentalTests {
}

// MARK: -

extension GuidoPitchAccidentalTests {
    @Test
    func equality() {
        #expect(Guido.Pitch.Accidental.sharp == .sharp)
    }

    @Test
    func inequality_allCasesDistinct() {
        let cases: [Guido.Pitch.Accidental] = [.doubleFlat, .doubleSharp, .flat, .natural, .sharp]

        for (index, lhs) in cases.enumerated() {
            for (otherIndex, rhs) in cases.enumerated() where index != otherIndex {
                #expect(lhs != rhs)
            }
        }
    }
}
