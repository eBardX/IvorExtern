// © 2025–2026 John Gary Pusey (see LICENSE.md)

import Foundation
@testable import IvorExtern
import Testing

struct MusicXMLImporterTests {
}

// MARK: -

extension MusicXMLImporterTests {
    @Test
    func read_emptyData_throws() {
        let wrapper = FileWrapper(regularFileWithContents: Data())

        #expect(throws: (any Error).self) {
            try MusicXML.Importer().read(from: wrapper, as: .musicXML)
        }
    }

    @Test
    func read_unsupportedFormat_throws() {
        let wrapper = FileWrapper(regularFileWithContents: Data())

        #expect(throws: (any Error).self) {
            try MusicXML.Importer().read(from: wrapper, as: .midi)
        }
    }

    @Test
    func readableFileFormats_containsMXLAndMusicXML() {
        let formats = MusicXML.Importer().readableFileFormats

        #expect(formats.contains(.mxl))
        #expect(formats.contains(.musicXML))
    }
}
