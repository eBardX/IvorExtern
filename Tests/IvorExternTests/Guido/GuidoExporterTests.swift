// © 2025–2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import Testing

struct GuidoExporterTests {
}

// MARK: -

extension GuidoExporterTests {
    @Test
    func write_alwaysThrows() {
        #expect(throws: (any Error).self) {
            try Guido.Exporter().write(works: [], as: .gmn)
        }
    }

    @Test
    func writableFileFormats_isEmpty() {
        #expect(Guido.Exporter().writableFileFormats.isEmpty)
    }
}
