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
    func importFileFormat_unknownExtension() {
        #expect(ImportFileFormat.importFileFormat(for: "xyz") == nil)
        #expect(ImportFileFormat.importFileFormat(for: "") == nil)
    }

    @Test
    func supportedFilenameExtensions_notEmpty() {
        #expect(!ImportFileFormat.supportedFilenameExtensions.isEmpty)
    }
}
