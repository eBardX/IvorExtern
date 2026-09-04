// © 2025–2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import IvorTiming
import IvorTuning
import Testing

struct FileFormatTests {
}

// MARK: -

extension FileFormatTests {
    @Test
    func description_returnsDisplayName() {
        let fileFormat = FileFormat(displayName: "Test Format")

        #expect(fileFormat.description == "Test Format")
    }

    @Test
    func equality_sameInstance() {
        let fileFormat = FileFormat(displayName: "Test Format")
        let other = fileFormat

        #expect(fileFormat == other)
    }

    @Test
    func inequality_differentInstancesWithSameFields() {
        let fileFormat = FileFormat(displayName: "Test Format")
        let other = FileFormat(displayName: "Test Format")

        #expect(fileFormat != other)
    }

    @Test
    func init_omittedValues_defaultToEmpty() {
        let fileFormat = FileFormat(displayName: "Test Format")

        #expect(fileFormat.filenameExtensions.isEmpty)
        #expect(fileFormat.mimeTypes.isEmpty)
        #expect(fileFormat.pitchNotations.isEmpty)
        #expect(fileFormat.timeBases.isEmpty)
    }

    @Test
    func init_setsProperties() {
        let fileFormat = FileFormat(displayName: "Test Format",
                                    filenameExtensions: ["tst"],
                                    mimeTypes: ["application/test"],
                                    pitchNotations: [.standard],
                                    timeBases: [.beat])

        #expect(fileFormat.displayName == "Test Format")
        #expect(fileFormat.filenameExtensions == ["tst"])
        #expect(fileFormat.mimeTypes == ["application/test"])
        #expect(fileFormat.pitchNotations == [.standard])
        #expect(fileFormat.timeBases == [.beat])
    }

    @Test
    func preferredFilenameExtension_empty_returnsNil() {
        let fileFormat = FileFormat(displayName: "Test Format")

        #expect(fileFormat.preferredFilenameExtension == nil)
    }

    @Test
    func preferredFilenameExtension_nonEmpty_returnsFirst() {
        let fileFormat = FileFormat(displayName: "Test Format",
                                    filenameExtensions: ["tst", "test"])

        #expect(fileFormat.preferredFilenameExtension == "tst")
    }

    @Test
    func preferredMIMEType_empty_returnsNil() {
        let fileFormat = FileFormat(displayName: "Test Format")

        #expect(fileFormat.preferredMIMEType == nil)
    }

    @Test
    func preferredMIMEType_nonEmpty_returnsFirst() {
        let fileFormat = FileFormat(displayName: "Test Format",
                                    mimeTypes: ["application/test", "application/x-test"])

        #expect(fileFormat.preferredMIMEType == "application/test")
    }
}
