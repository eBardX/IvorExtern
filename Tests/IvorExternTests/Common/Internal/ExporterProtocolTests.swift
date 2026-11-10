// © 2026 John Gary Pusey (see LICENSE.md)

import Foundation
@testable import IvorExtern
import IvorModel
import Testing
import XestiTools

struct ExporterProtocolTests {
}

// MARK: -

extension ExporterProtocolTests {
    @Test
    func write_supportedFileFormat_writesFile() throws {
        let exporter: any ExporterProtocol = ABC.Exporter()
        let file = try exporter.write(works: [standardBeatWork(parts: [])],
                                      as: .abc,
                                      options: .default)

        #expect(file.regularFileContents?.isEmpty == false)
    }

    @Test
    func write_unsupportedFileFormat_throws() {
        let exporter: any ExporterProtocol = ABC.Exporter()

        #expect(throws: (any Error).self) {
            try exporter.write(works: [standardBeatWork(parts: [])],
                               as: .gmn,
                               options: .default)
        }
    }
}
