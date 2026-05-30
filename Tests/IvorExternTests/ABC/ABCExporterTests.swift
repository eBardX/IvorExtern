// © 2025–2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import Testing

struct ABCExporterTests {
}

// MARK: -

extension ABCExporterTests {
    @Test
    func write_alwaysThrows() {
        #expect(throws: (any Error).self) {
            try ABC.Exporter().write(works: [], as: .abc)
        }
    }

    @Test
    func writableFileFormats_isEmpty() {
        #expect(ABC.Exporter().writableFileFormats.isEmpty)
    }
}
