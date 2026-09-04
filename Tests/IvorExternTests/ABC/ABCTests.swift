// © 2025–2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import Testing

struct ABCTests {
}

// MARK: -

extension ABCTests {
    @Test
    func exporter_writableFileFormats() {
        let subject = ABC()

        #expect(subject.exporter.writableFileFormats == [.abc])
    }

    @Test
    func importer_readableFileFormats() {
        let subject = ABC()

        #expect(subject.importer.readableFileFormats == [.abc])
    }
}
