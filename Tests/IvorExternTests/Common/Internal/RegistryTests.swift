// © 2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import Testing

struct RegistryTests {
}

// MARK: -

extension RegistryTests {
    @Test
    func exporters_notEmpty() {
        #expect(!exporters.isEmpty)
    }

    @Test
    func exporters_onlyIncludeCandidatesWithWritableFileFormats() {
        #expect(exporters.allSatisfy { !$0.writableFileFormats.isEmpty })
    }

    @Test
    func exporters_writeEveryFileFormat() {
        let fileFormats: [FileFormat] = [.abc, .dkm, .gmn, .midi, .musicXML, .mxl]
        let writable = exporters.flatMap(\.writableFileFormats)

        #expect(writable.count == fileFormats.count)
        #expect(fileFormats.allSatisfy { writable.contains($0) })
    }

    @Test
    func importers_notEmpty() {
        #expect(!importers.isEmpty)
    }

    @Test
    func importers_onlyIncludeCandidatesWithReadableFileFormats() {
        #expect(importers.allSatisfy { !$0.readableFileFormats.isEmpty })
    }

    @Test
    func importers_readEveryFileFormat() {
        let fileFormats: [FileFormat] = [.abc, .dkm, .gmn, .midi, .musicXML, .mxl]
        let readable = importers.flatMap(\.readableFileFormats)

        #expect(readable.count == fileFormats.count)
        #expect(fileFormats.allSatisfy { readable.contains($0) })
    }
}
