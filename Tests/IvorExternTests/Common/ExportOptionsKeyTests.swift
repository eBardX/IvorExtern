// © 2026 John Gary Pusey (see LICENSE.md)

import IvorExtern
import Testing

struct ExportOptionsKeyTests {
}

// MARK: -

extension ExportOptionsKeyTests {
    @Test
    func allCases() {
        #expect(ExportOptions.Key.allCases == [.midiTicksPerQuarterNote, .midiTimeCode])
    }

    @Test
    func hashable() {
        let keys = Set(ExportOptions.Key.allCases + ExportOptions.Key.allCases)

        #expect(keys.count == ExportOptions.Key.allCases.count)
    }
}
