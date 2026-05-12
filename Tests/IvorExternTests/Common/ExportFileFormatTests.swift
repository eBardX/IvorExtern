import IvorExtern
import Testing

struct ExportFileFormatTests {
}

// MARK: -

extension ExportFileFormatTests {
    @Test
    func canWrite_matchingExtension() throws {
        let fmt = try #require(ExportFileFormat.exportFileFormat(for: "dkm"))

        #expect(fmt.canWrite(to: "dkm"))
    }

    @Test
    func canWrite_nonMatchingExtension() throws {
        let fmt = try #require(ExportFileFormat.exportFileFormat(for: "dkm"))

        #expect(!fmt.canWrite(to: "xyz"))
    }

    @Test
    func displayName_notEmpty() throws {
        let fmt = try #require(ExportFileFormat.exportFileFormat(for: "dkm"))

        #expect(!fmt.displayName.isEmpty)
    }

    @Test
    func exportFileFormat_knownExtension() {
        #expect(ExportFileFormat.exportFileFormat(for: "dkm") != nil)
        #expect(ExportFileFormat.exportFileFormat(for: "midi") != nil)
        #expect(ExportFileFormat.exportFileFormat(for: "mid") != nil)
    }

    @Test
    func exportFileFormat_unknownExtension() {
        #expect(ExportFileFormat.exportFileFormat(for: "xyz") == nil)
        #expect(ExportFileFormat.exportFileFormat(for: "") == nil)
    }

    @Test
    func filenameExtensions_notEmpty() throws {
        let fmt = try #require(ExportFileFormat.exportFileFormat(for: "dkm"))

        #expect(!fmt.filenameExtensions.isEmpty)
    }

    @Test
    func supportedFilenameExtensions_notEmpty() {
        #expect(!ExportFileFormat.supportedFilenameExtensions.isEmpty)
    }
}
