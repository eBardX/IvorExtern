// © 2025–2026 John Gary Pusey (see LICENSE.md)

import IvorExtern
import Testing

struct ImportFileFormatTests {
}

// MARK: -

extension ImportFileFormatTests {
    @Test
    func canRead_matchingExtension() throws {
        let fmt = try #require(ImportFileFormat.importFileFormat(for: "abz"))

        #expect(fmt.canRead(from: "abz"))
    }

    @Test
    func canRead_matchingMIMEType() throws {
        let fmt = try #require(ImportFileFormat.importFileFormat(for: "audio/midi"))

        #expect(fmt.canRead(from: "audio/midi"))
    }

    @Test
    func canRead_nonMatchingExtension() throws {
        let fmt = try #require(ImportFileFormat.importFileFormat(for: "abz"))

        #expect(!fmt.canRead(from: "xyz"))
    }

    @Test
    func displayName_notEmpty() throws {
        let fmt = try #require(ImportFileFormat.importFileFormat(for: "abz"))

        #expect(!fmt.displayName.isEmpty)
    }

    @Test
    func filenameExtensions_notEmpty() throws {
        let fmt = try #require(ImportFileFormat.importFileFormat(for: "abz"))

        #expect(!fmt.filenameExtensions.isEmpty)
    }

    @Test
    func importFileFormat_knownExtension() {
        #expect(ImportFileFormat.importFileFormat(for: "abz") != nil)
        #expect(ImportFileFormat.importFileFormat(for: "midi") != nil)
        #expect(ImportFileFormat.importFileFormat(for: "gmn") != nil)
        #expect(ImportFileFormat.importFileFormat(for: "musicxml") != nil)
    }

    @Test
    func importFileFormat_knownMIMEType() {
        #expect(ImportFileFormat.importFileFormat(for: "audio/midi") != nil)
        #expect(ImportFileFormat.importFileFormat(for: "text/vnd.abc") != nil)
        #expect(ImportFileFormat.importFileFormat(for: "application/vnd.recordare.musicxml+xml") != nil)
    }

    @Test
    func importFileFormat_unknownExtension() {
        #expect(ImportFileFormat.importFileFormat(for: "xyz") == nil)
        #expect(ImportFileFormat.importFileFormat(for: "") == nil)
    }

    @Test
    func mimeTypes_notEmpty() throws {
        let fmt = try #require(ImportFileFormat.importFileFormat(for: "midi"))

        #expect(!fmt.mimeTypes.isEmpty)
    }

    @Test
    func preferredFilenameExtension_notNil() throws {
        let fmt = try #require(ImportFileFormat.importFileFormat(for: "midi"))

        #expect(fmt.preferredFilenameExtension != nil)
    }

    @Test
    func preferredFilenameExtensions_notEmpty() {
        #expect(!ImportFileFormat.preferredFilenameExtensions.isEmpty)
    }

    @Test
    func preferredMIMEType_notNil() throws {
        let fmt = try #require(ImportFileFormat.importFileFormat(for: "audio/midi"))

        #expect(fmt.preferredMIMEType != nil)
    }

    @Test
    func preferredMIMETypes_notEmpty() {
        #expect(!ImportFileFormat.preferredMIMETypes.isEmpty)
    }

    @Test
    func supportedFilenameExtensions_notEmpty() {
        #expect(!ImportFileFormat.supportedFilenameExtensions.isEmpty)
    }

    @Test
    func supportedMIMETypes_notEmpty() {
        #expect(!ImportFileFormat.supportedMIMETypes.isEmpty)
    }
}
