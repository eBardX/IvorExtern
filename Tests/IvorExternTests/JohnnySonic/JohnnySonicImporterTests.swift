// © 2025–2026 John Gary Pusey (see LICENSE.md)

import Foundation
@testable import IvorExtern
import Testing

struct JohnnySonicImporterTests {
}

// MARK: -

extension JohnnySonicImporterTests {
    @Test
    func read_alwaysThrows() {
        let wrapper = FileWrapper(regularFileWithContents: Data())

        #expect(throws: (any Error).self) {
            try JohnnySonic.Importer().read(from: wrapper, as: .dkm)
        }
    }

    @Test
    func readableFileFormats_isEmpty() {
        #expect(JohnnySonic.Importer().readableFileFormats.isEmpty)
    }
}
