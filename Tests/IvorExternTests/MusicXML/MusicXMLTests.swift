// © 2025–2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import Testing

struct MusicXMLTests {
}

// MARK: -

extension MusicXMLTests {
    @Test
    func exporter_writableFileFormats() {
        let subject = MusicXML()

        #expect(subject.exporter.writableFileFormats == [.musicXML, .mxl])
    }

    @Test
    func importer_readableFileFormats() {
        let subject = MusicXML()

        #expect(subject.importer.readableFileFormats == [.musicXML, .mxl])
    }
}
