// © 2025–2026 John Gary Pusey (see LICENSE.md)

import Foundation
@testable import IvorExtern
import Testing

struct GuidoImporterTests {
}

// MARK: -

extension GuidoImporterTests {
    @Test
    func read_emptyData_throws() {
        let wrapper = FileWrapper(regularFileWithContents: Data())

        #expect(throws: (any Error).self) {
            try Guido.Importer().read(from: wrapper, as: .gmn)
        }
    }

    @Test
    func read_unsupportedFormat_throws() {
        let wrapper = FileWrapper(regularFileWithContents: Data())

        #expect(throws: (any Error).self) {
            try Guido.Importer().read(from: wrapper, as: .midi)
        }
    }

    @Test
    func readableFileFormats_containsGMN() {
        #expect(Guido.Importer().readableFileFormats.contains(.gmn))
    }
}
