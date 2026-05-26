// © 2025–2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import IvorGuido
import Testing
import XestiTools

struct GuidoErrorTests {
}

// MARK: -

extension GuidoErrorTests {
    @Test
    func convertFailure_message() {
        let error = Guido.Error.convertFailure(nil)

        #expect(error.message == "Unable to convert Guido score to Ivor work")
    }

    @Test
    func incompleteDuration_message() throws {
        let duration = try #require(GMNDuration(numerator: 1, denominator: 4))
        let error = Guido.Error.incompleteDuration(duration)

        #expect(error.message.hasPrefix("Incomplete Guido duration:"))
    }

    @Test
    func nestedChord_message() {
        let error = Guido.Error.nestedChord

        #expect(error.message == "Nested chords are disallowed")
    }

    @Test
    func parseFailure_message() {
        let error = Guido.Error.parseFailure(nil)

        #expect(error.message == "Unable to parse Guido score")
    }

    @Test
    func unrecognizedPitchAccidental_message() {
        let error = Guido.Error.unrecognizedPitchAccidental(.flat)

        #expect(error.message == "Unrecognized Guido pitch accidental: \u{2018}flat\u{2019}")
    }

    @Test
    func unrecognizedPitchName_message() {
        let error = Guido.Error.unrecognizedPitchName(.a)

        #expect(error.message == "Unrecognized Guido pitch name: \u{2018}a\u{2019}")
    }

    @Test
    func unrecognizedPitchOctave_message() {
        let error = Guido.Error.unrecognizedPitchOctave(4)

        #expect(error.message == "Unrecognized Guido pitch octave: \u{2018}4\u{2019}")
    }

    @Test
    func unsupportedFileFormat_message() {
        let error = Guido.Error.unsupportedFileFormat("gmn")

        #expect(error.message == "Unsupported file format: \u{2018}gmn\u{2019}")
    }

    @Test
    func unsupportedSymbol_message() {
        let error = Guido.Error.unsupportedSymbol(.variable("test"))

        #expect(error.message.hasPrefix("Unsupported symbol:"))
    }
}
