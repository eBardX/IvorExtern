// © 2025–2026 John Gary Pusey (see LICENSE.md)

import Foundation
@testable import IvorExtern
import Testing

struct ABCImporterTests {
}

// MARK: -

extension ABCImporterTests {
    @Test
    func read_emptyData_throws() {
        let wrapper = FileWrapper(regularFileWithContents: Data())

        #expect(throws: (any Error).self) {
            try ABC.Importer().read(from: wrapper, as: .abc)
        }
    }

    @Test
    func read_unsupportedFormat_throws() {
        let wrapper = FileWrapper(regularFileWithContents: Data())

        #expect(throws: (any Error).self) {
            try ABC.Importer().read(from: wrapper, as: .midi)
        }
    }

    @Test
    func readableFileFormats_containsABC() {
        #expect(ABC.Importer().readableFileFormats.contains(.abc))
    }
}
