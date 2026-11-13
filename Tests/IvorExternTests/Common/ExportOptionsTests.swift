// © 2026 John Gary Pusey (see LICENSE.md)

import IvorExtern
import Testing

struct ExportOptionsTests {
}

// MARK: -

extension ExportOptionsTests {
    @Test
    func default_changesNothing() {
        #expect(ExportOptions.default.midi == MIDIExportOptions())
        #expect(ExportOptions.default == ExportOptions())
    }

    @Test
    func equatable_comparesMIDIOptions() {
        #expect(ExportOptions(midi: MIDIExportOptions(ticksPerQuarterNote: 960)) != ExportOptions())
    }
}
