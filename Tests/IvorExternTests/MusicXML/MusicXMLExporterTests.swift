// © 2025–2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import Testing

struct MusicXMLExporterTests {
}

// MARK: -

extension MusicXMLExporterTests {
    @Test
    func write_alwaysThrows() {
        #expect(throws: (any Error).self) {
            try MusicXML.Exporter().write(works: [], as: .musicXML)
        }
    }

    @Test
    func writableFileFormats_isEmpty() {
        #expect(MusicXML.Exporter().writableFileFormats.isEmpty)
    }
}
