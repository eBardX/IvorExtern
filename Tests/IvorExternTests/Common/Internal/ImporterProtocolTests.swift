// © 2026 John Gary Pusey (see LICENSE.md)

import Foundation
@testable import IvorExtern
import IvorModel
import Testing

struct ImporterProtocolTests {
}

// MARK: -

extension ImporterProtocolTests {
    @Test
    func read_supportedFileFormat_readsWorks() throws {
        let importer: any ImporterProtocol = ABC.Importer()
        let file = FileWrapper(regularFileWithContents: Data("X:1\nT:Tune\nK:C\nC D E F|\n".utf8))
        let works = try importer.read(from: file,
                                      as: .abc)

        #expect(works.map(\.name) == ["Tune"])
    }

    @Test
    func read_unsupportedFileFormat_throws() {
        let importer: any ImporterProtocol = ABC.Importer()
        let file = FileWrapper(regularFileWithContents: Data("X:1\nT:Tune\nK:C\nC D E F|\n".utf8))

        #expect(throws: (any Error).self) {
            try importer.read(from: file,
                              as: .gmn)
        }
    }
}
