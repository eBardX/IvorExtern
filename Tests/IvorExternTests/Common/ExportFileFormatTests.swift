// © 2025–2026 John Gary Pusey (see LICENSE.md)

import IvorExtern
import IvorModel
import IvorTiming
import IvorTuning
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
    func canWrite_matchingMIMEType() throws {
        let fmt = try #require(ExportFileFormat.exportFileFormat(for: "audio/midi"))

        #expect(fmt.canWrite(to: "audio/midi"))
    }

    @Test
    func canWrite_nonMatchingExtension() throws {
        let fmt = try #require(ExportFileFormat.exportFileFormat(for: "dkm"))

        #expect(!fmt.canWrite(to: "xyz"))
    }

    @Test
    func canWrite_work_midi() throws {
        let fmt = try #require(ExportFileFormat.exportFileFormat(for: "midi"))

        #expect(fmt.canWrite(_makeWork(.beat, .keyboard)))
        #expect(fmt.canWrite(_makeWork(.wall, .keyboard)))
        #expect(!fmt.canWrite(_makeWork(.beat, .standard)))
        #expect(!fmt.canWrite(_makeWork(.beat, .absolute)))
    }

    @Test(arguments: ["abc", "dkm", "gmn", "midi", "musicxml", "mxl"])
    func canWrite_work_matchesTimeBasesAndPitchNotations(tag: String) throws {
        let fmt = try #require(ExportFileFormat.exportFileFormat(for: tag))

        for timeBasis in [TimeBasis.beat, .wall] {
            for pitchNotation in [PitchNotation.absolute, .keyboard, .standard] {
                let expected = fmt.timeBases.contains(timeBasis) && fmt.pitchNotations.contains(pitchNotation)

                #expect(fmt.canWrite(_makeWork(timeBasis, pitchNotation)) == expected)
            }
        }
    }

    @Test
    func displayName_notEmpty() throws {
        let fmt = try #require(ExportFileFormat.exportFileFormat(for: "dkm"))

        #expect(!fmt.displayName.isEmpty)
    }

    @Test
    func exportFileFormat_knownExtension() {
        #expect(ExportFileFormat.exportFileFormat(for: "abc") != nil)
        #expect(ExportFileFormat.exportFileFormat(for: "dkm") != nil)
        #expect(ExportFileFormat.exportFileFormat(for: "gmn") != nil)
        #expect(ExportFileFormat.exportFileFormat(for: "midi") != nil)
        #expect(ExportFileFormat.exportFileFormat(for: "mid") != nil)
        #expect(ExportFileFormat.exportFileFormat(for: "musicxml") != nil)
        #expect(ExportFileFormat.exportFileFormat(for: "mxl") != nil)
    }

    @Test
    func exportFileFormat_knownMIMEType() {
        #expect(ExportFileFormat.exportFileFormat(for: "audio/midi") != nil)
        #expect(ExportFileFormat.exportFileFormat(for: "audio/x-midi") != nil)
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
    func mimeTypes_notEmpty() throws {
        let fmt = try #require(ExportFileFormat.exportFileFormat(for: "midi"))

        #expect(!fmt.mimeTypes.isEmpty)
    }

    @Test
    func preferredFilenameExtension_notNil() throws {
        let fmt = try #require(ExportFileFormat.exportFileFormat(for: "midi"))

        #expect(fmt.preferredFilenameExtension != nil)
    }

    @Test
    func preferredFilenameExtensions_notEmpty() {
        #expect(!ExportFileFormat.preferredFilenameExtensions.isEmpty)
    }

    @Test
    func preferredMIMEType_notNil() throws {
        let fmt = try #require(ExportFileFormat.exportFileFormat(for: "audio/midi"))

        #expect(fmt.preferredMIMEType != nil)
    }

    @Test
    func preferredMIMETypes_notEmpty() {
        #expect(!ExportFileFormat.preferredMIMETypes.isEmpty)
    }

    @Test
    func supportedFilenameExtensions_notEmpty() {
        #expect(!ExportFileFormat.supportedFilenameExtensions.isEmpty)
    }

    @Test
    func supportedMIMETypes_notEmpty() {
        #expect(!ExportFileFormat.supportedMIMETypes.isEmpty)
    }
}

// MARK: -

extension ExportFileFormatTests {
    private func _makeWork(_ timeBasis: TimeBasis,
                           _ pitchNotation: PitchNotation) -> Work {
        Work(name: "Work",
             content: .empty(timeBasis: timeBasis,
                             pitchNotation: pitchNotation))
    }
}
