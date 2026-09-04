// © 2025–2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import Testing

struct GuidoTests {
}

// MARK: -

extension GuidoTests {
    @Test
    func exporter_writableFileFormats() {
        let subject = Guido()

        #expect(subject.exporter.writableFileFormats == [.gmn])
    }

    @Test
    func importer_readableFileFormats() {
        let subject = Guido()

        #expect(subject.importer.readableFileFormats == [.gmn])
    }
}
