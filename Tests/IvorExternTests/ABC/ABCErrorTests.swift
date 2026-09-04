// © 2025–2026 John Gary Pusey (see LICENSE.md)

import IvorABC
@testable import IvorExtern
import IvorTiming
import IvorTuning
import Testing
import XestiTools

struct ABCErrorTests {
}

// MARK: -

extension ABCErrorTests {
    @Test
    func convertFailure_message() {
        let error = ABC.Error.convertFailure(nil)

        #expect(error.message == "Unable to convert ABC file to Ivor work")
    }

    @Test
    func formatFailure_message() {
        let error = ABC.Error.formatFailure(nil)

        #expect(error.message == "Unable to format ABC tunebook")
    }

    @Test
    func noWorksToExport_message() {
        let error = ABC.Error.noWorksToExport

        #expect(error.message == "No works to export")
    }

    @Test
    func parseFailure_message() {
        let error = ABC.Error.parseFailure(nil)

        #expect(error.message == "Unable to parse ABC file")
    }

    @Test
    func unrecognizedPitchAccidental_message() {
        let error = ABC.Error.unrecognizedPitchAccidental(.flat)

        #expect(error.message == "Unrecognized ABC pitch accidental: \u{2018}flat\u{2019}")
    }

    @Test
    func unrecognizedPitchLetter_message() {
        let error = ABC.Error.unrecognizedPitchLetter(.a)

        #expect(error.message == "Unrecognized ABC pitch letter: \u{2018}a\u{2019}")
    }

    @Test
    func unrecognizedPitchOctave_message() {
        let error = ABC.Error.unrecognizedPitchOctave(5)

        #expect(error.message == "Unrecognized ABC pitch octave: \u{2018}5\u{2019}")
    }

    @Test
    func unrepresentableDuration_message() {
        let error = ABC.Error.unrepresentableDuration("1/11")

        #expect(error.message == "Unrepresentable duration: \u{2018}1/11\u{2019}")
    }

    @Test
    func unrepresentablePitch_message() {
        let error = ABC.Error.unrepresentablePitch("C-2")

        #expect(error.message == "Unrepresentable pitch: \u{2018}C-2\u{2019}")
    }

    @Test
    func unresolvableMacro_message() {
        let error = ABC.Error.unresolvableMacro("n")

        #expect(error.message == "Unresolvable macro: \u{2018}n\u{2019}")
    }

    @Test
    func unsupportedFileFormat_message() {
        let error = ABC.Error.unsupportedFileFormat("xyz")

        #expect(error.message == "Unsupported file format: \u{2018}xyz\u{2019}")
    }

    @Test
    func unsupportedPitchNotation_message() {
        let error = ABC.Error.unsupportedPitchNotation(.keyboard)

        #expect(error.message == "Unsupported pitch notation: keyboard")
    }

    @Test
    func unsupportedTimeBasis_message() {
        let error = ABC.Error.unsupportedTimeBasis(.wall)

        #expect(error.message == "Unsupported time basis: wall")
    }

    @Test
    func validationFailure_message() {
        let error = ABC.Error.validationFailure([.missingKey(0), .missingTuneTitle(0)])

        #expect(error.message == "ABC tunebook failed validation: Tune 0 has no key (K:) field; Tune 0 has no title (T:) field")
    }
}
