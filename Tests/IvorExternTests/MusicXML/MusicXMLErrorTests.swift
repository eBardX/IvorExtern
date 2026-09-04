// © 2025–2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import IvorMusicXML
import IvorTiming
import IvorTuning
import Testing
import XestiTools

struct MusicXMLErrorTests {
}

// MARK: -

extension MusicXMLErrorTests {
    @Test
    func convertFailure_message() {
        let error = MusicXML.Error.convertFailure(nil)

        #expect(error.message == "Unable to convert MusicXML score to Ivor work")
    }

    @Test
    func formatFailure_message() {
        let error = MusicXML.Error.formatFailure(nil)

        #expect(error.message == "Unable to format MusicXML score")
    }

    @Test
    func invalidRootFileMediaType_message() {
        let error = MusicXML.Error.invalidRootFileMediaType("text/plain")

        #expect(error.message == "Invalid root file media type: text/plain")
    }

    @Test
    func multipleWorksNotSupported_message() {
        let error = MusicXML.Error.multipleWorksNotSupported

        #expect(error.message == "Multiple works are not supported")
    }

    @Test
    func noRootFileFound_message() {
        let error = MusicXML.Error.noRootFileFound

        #expect(error.message == "No root files found in container")
    }

    @Test
    func noWorksToExport_message() {
        let error = MusicXML.Error.noWorksToExport

        #expect(error.message == "No works to export")
    }

    @Test
    func parseFailure_message() {
        let error = MusicXML.Error.parseFailure(nil)

        #expect(error.message == "Unable to parse MusicXML score")
    }

    @Test
    func partMismatch_message() {
        let error = MusicXML.Error.partMismatch

        #expect(error.message == "Number of MusicXML score parts does not match number of MusicXML parts")
    }

    @Test
    func unrecognizedPitchAccidental_message() {
        let error = MusicXML.Error.unrecognizedPitchAccidental(-1)

        #expect(error.message == "Unrecognized MusicXML pitch accidental: \u{2018}-1.0\u{2019}")
    }

    @Test
    func unrecognizedPitchOctave_message() {
        let error = MusicXML.Error.unrecognizedPitchOctave(4)

        #expect(error.message == "Unrecognized MusicXML pitch octave: \u{2018}4\u{2019}")
    }

    @Test
    func unsupportedFileFormat_message() {
        let error = MusicXML.Error.unsupportedFileFormat("mxl")

        #expect(error.message == "Unsupported file format: \u{2018}mxl\u{2019}")
    }

    @Test
    func unsupportedPitchNotation_message() {
        let error = MusicXML.Error.unsupportedPitchNotation(.keyboard)

        #expect(error.message == "Unsupported pitch notation: keyboard")
    }

    @Test
    func unsupportedScoreFormat_message() {
        let error = MusicXML.Error.unsupportedScoreFormat("timewise")

        #expect(error.message == "Unsupported MusicXML score format: \u{2018}timewise\u{2019}")
    }

    @Test
    func unsupportedTimeBasis_message() {
        let error = MusicXML.Error.unsupportedTimeBasis(.wall)

        #expect(error.message == "Unsupported time basis: wall")
    }

    @Test
    func validationFailure_message() {
        let error = MusicXML.Error.validationFailure([.unusedScorePart("P2")])

        #expect(error.message == "MusicXML score failed validation: Score-part P2 is referenced by no part")
    }
}
