// © 2025–2026 John Gary Pusey (see LICENSE.md)

import IvorABC
@testable import IvorExtern
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
    func unsupportedFileFormat_message() {
        let error = ABC.Error.unsupportedFileFormat("xyz")

        #expect(error.message == "Unsupported file format: \u{2018}xyz\u{2019}")
    }
}
