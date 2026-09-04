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
    func importers_notEmpty() {
        #expect(!importers.isEmpty)
    }

    @Test
    func importers_onlyIncludeCandidatesWithReadableFileFormats() {
        #expect(importers.allSatisfy { !$0.readableFileFormats.isEmpty })
    }
}
