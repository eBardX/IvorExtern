// © 2025–2026 John Gary Pusey (see LICENSE.md)

import Foundation
@testable import IvorExtern
import IvorGuido
import IvorTiming
import IvorTuning
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
    func formatFailure_message() {
        let error = Guido.Error.formatFailure(nil)

        #expect(error.message == "Unable to format Guido score")
    }

    @Test
    func multipleWorksNotSupported_message() {
        let error = Guido.Error.multipleWorksNotSupported

        #expect(error.message == "Multiple works are not supported")
    }

    @Test
    func noWorksToExport_message() {
        let error = Guido.Error.noWorksToExport

        #expect(error.message == "No works to export")
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
    func unsupportedEvent_message() throws {
        let score = try Guido.Parser().parse(Data("[ s1:0: ]".utf8))
        let voice = try #require(score.voices.first)
        let event = try #require(voice.symbols.first { if case .tablature = $0 { true } else { false } })

        let error = Guido.Error.unsupportedEvent(event)

        #expect(error.message.hasPrefix("Unsupported event:"))
    }

    @Test
    func unsupportedFileFormat_message() {
        let error = Guido.Error.unsupportedFileFormat("gmn")

        #expect(error.message == "Unsupported file format: \u{2018}gmn\u{2019}")
    }

    @Test
    func unsupportedPitchNotation_message() {
        let error = Guido.Error.unsupportedPitchNotation(.keyboard)

        #expect(error.message == "Unsupported pitch notation: keyboard")
    }

    @Test
    func unsupportedTimeBasis_message() {
        let error = Guido.Error.unsupportedTimeBasis(.wall)

        #expect(error.message == "Unsupported time basis: wall")
    }

    @Test
    func validationFailure_message() {
        let error = Guido.Error.validationFailure([.missingTagBody(GMNTag.Name("slur")),
                                                   .unexpectedTagBody(GMNTag.Name("title"))])

        #expect(error.message == "Guido score failed validation: Tag ‘\\slur’ requires a body; Tag ‘\\title’ takes no body")
    }
}
