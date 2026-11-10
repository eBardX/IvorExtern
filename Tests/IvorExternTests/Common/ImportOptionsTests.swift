// © 2026 John Gary Pusey (see LICENSE.md)

import IvorExtern
import IvorModel
import Testing

struct ImportOptionsTests {
}

// MARK: -

extension ImportOptionsTests {
    @Test
    func default_changesNothing() {
        #expect(ImportOptions.default.pedalSimplification == nil)
        #expect(ImportOptions.default == ImportOptions())
    }

    @Test
    func equatable_comparesPedalSimplification() {
        #expect(ImportOptions(pedalSimplification: .snap) == ImportOptions(pedalSimplification: .snap)) // swiftlint:disable:this identical_operands
        #expect(ImportOptions(pedalSimplification: .snap) != ImportOptions())
    }

    @Test
    func key_allCases() {
        #expect(ImportOptions.Key.allCases == [.pedalSimplification])
    }
}
