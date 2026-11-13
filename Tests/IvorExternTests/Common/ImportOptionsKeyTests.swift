// © 2026 John Gary Pusey (see LICENSE.md)

import IvorExtern
import Testing

struct ImportOptionsKeyTests {
}

// MARK: -

extension ImportOptionsKeyTests {
    @Test
    func allCases() {
        #expect(ImportOptions.Key.allCases == [.pedalSimplification])
    }

    @Test
    func hashable() {
        let keys = Set(ImportOptions.Key.allCases + ImportOptions.Key.allCases)

        #expect(keys.count == ImportOptions.Key.allCases.count)
    }
}
