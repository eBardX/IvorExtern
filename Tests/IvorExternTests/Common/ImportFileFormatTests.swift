// © 2025–2026 John Gary Pusey (see LICENSE.md)

import Foundation
import IvorExtern
import IvorModel
import Testing
import XestiTools

struct ImportFileFormatTests {
}

// MARK: -

extension ImportFileFormatTests {
    @Test
    func canRead_matchingExtension() throws {
        let fmt = try #require(ImportFileFormat.importFileFormat(for: "abc"))

        #expect(fmt.canRead(from: "abc"))
    }

    @Test
    func canRead_matchingMIMEType() throws {
        let fmt = try #require(ImportFileFormat.importFileFormat(for: "audio/midi"))

        #expect(fmt.canRead(from: "audio/midi"))
    }

    @Test
    func canRead_nonMatchingExtension() throws {
        let fmt = try #require(ImportFileFormat.importFileFormat(for: "abc"))

        #expect(!fmt.canRead(from: "xyz"))
    }

    @Test
    func displayName_notEmpty() throws {
        let fmt = try #require(ImportFileFormat.importFileFormat(for: "abc"))

        #expect(!fmt.displayName.isEmpty)
    }

    @Test
    func filenameExtensions_notEmpty() throws {
        let fmt = try #require(ImportFileFormat.importFileFormat(for: "abc"))

        #expect(!fmt.filenameExtensions.isEmpty)
    }

    @Test
    func importFileFormat_knownExtension() {
        #expect(ImportFileFormat.importFileFormat(for: "abc") != nil)
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
    func pitchNotations_notEmpty() throws {
        let fmt = try #require(ImportFileFormat.importFileFormat(for: "abc"))

        #expect(!fmt.pitchNotations.isEmpty)
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
    func read_invalidFile_throwsReadFailure() throws {
        let fmt = try #require(ImportFileFormat.importFileFormat(for: "midi"))
        let file = FileWrapper(regularFileWithContents: Data("not a MIDI file".utf8))

        let error = #expect(throws: ImportFileFormat.Error.self) {
            try fmt.read(from: file)
        }

        #expect(error?.message == "Unable to read works from file")
        #expect(error?.cause != nil)
    }

    @Test
    func read_pedalSimplification_simplifiesEveryTable() throws {
        let fmt = try #require(ImportFileFormat.importFileFormat(for: "midi"))
        let file = try FileWrapper(regularFileWithContents: Fixtures.pedalMIDI())
        let asReadWork = try #require(fmt.read(from: file).first)
        let snappedWork = try #require(fmt.read(from: file,
                                                options: ImportOptions(pedalSimplification: .snap)).first)
        let asRead = try #require(keyboardBeatParts(of: asReadWork)?.first)
        let snapped = try #require(keyboardBeatParts(of: snappedWork)?.first)
        let asReadSustain = try #require(asRead.pedals[.sustain])
        let snappedSustain = try #require(snapped.pedals[.sustain])

        #expect(snappedSustain.count < asReadSustain.count)
        #expect(snappedSustain.allSatisfy { $0.level == .down || $0.level == .up })
        #expect(Set(snapped.pedals.keys) == Set(asRead.pedals.keys))
    }

    @Test
    func read_validFile() throws {
        let fmt = try #require(ImportFileFormat.importFileFormat(for: "abc"))
        let file = FileWrapper(regularFileWithContents: Data("X:1\nT:Tune\nK:C\nCDE|\n".utf8))

        let works = try fmt.read(from: file)

        #expect(works.count == 1)
        #expect(works.first?.name == "Tune")
    }

    @Test
    func supportedFilenameExtensions_notEmpty() {
        #expect(!ImportFileFormat.supportedFilenameExtensions.isEmpty)
    }

    @Test
    func supportedMIMETypes_notEmpty() {
        #expect(!ImportFileFormat.supportedMIMETypes.isEmpty)
    }

    @Test
    func supportedOptions_pedalSimplification() throws {
        for tag in ["abc", "gmn", "midi", "musicxml"] {
            let fmt = try #require(ImportFileFormat.importFileFormat(for: tag))

            #expect(fmt.supportedOptions == [.pedalSimplification])
        }
    }

    @Test
    func supportedPitchNotations_notEmpty() {
        #expect(!ImportFileFormat.supportedPitchNotations.isEmpty)
    }

    @Test
    func supportedTimeBases_notEmpty() {
        #expect(!ImportFileFormat.supportedTimeBases.isEmpty)
    }

    @Test
    func timeBases_notEmpty() throws {
        let fmt = try #require(ImportFileFormat.importFileFormat(for: "abc"))

        #expect(!fmt.timeBases.isEmpty)
    }
}
