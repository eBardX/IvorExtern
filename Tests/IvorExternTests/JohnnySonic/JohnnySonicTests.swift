// © 2025–2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import Testing

struct JohnnySonicTests {
}

// MARK: -

extension JohnnySonicTests {
    @Test
    func exporter_writableFileFormats() {
        let subject = JohnnySonic()

        #expect(subject.exporter.writableFileFormats == [.dkm])
    }

    @Test
    func importer_readableFileFormats() {
        let subject = JohnnySonic()

        #expect(subject.importer.readableFileFormats == [.dkm])
    }
}
