// © 2025–2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import IvorTiming
import IvorTuning
import Testing
import XestiTools

struct JohnnySonicErrorTests {
}

// MARK: -

extension JohnnySonicErrorTests {
    @Test
    func convertFailure_message() {
        let error = JohnnySonic.Error.convertFailure(nil)

        #expect(error.message == "Unable to convert Ivor work to JohnnySonic score")
    }

    @Test
    func formatFailure_message() {
        let error = JohnnySonic.Error.formatFailure(nil)

        #expect(error.message == "Unable to format JohnnySonic score")
    }

    @Test
    func inconsistentPitchNotation_message() {
        let error = JohnnySonic.Error.inconsistentPitchNotation

        #expect(error.message == "Score contains both absolute and keyboard pitch notations")
    }

    @Test
    func multipleWorksNotSupported_message() {
        let error = JohnnySonic.Error.multipleWorksNotSupported

        #expect(error.message == "Multiple works are not supported")
    }

    @Test
    func parseFailure_message() {
        let error = JohnnySonic.Error.parseFailure(nil)

        #expect(error.message == "Unable to parse JohnnySonic score")
    }

    @Test
    func unsupportedFileFormat_message() {
        let error = JohnnySonic.Error.unsupportedFileFormat("dkm")

        #expect(error.message == "Unsupported file format: \u{2018}dkm\u{2019}")
    }

    @Test
    func unsupportedPitchNotation_message() {
        let error = JohnnySonic.Error.unsupportedPitchNotation(.absolute)

        #expect(error.message.hasPrefix("Unsupported pitch notation:"))
    }

    @Test
    func unsupportedTimeBasis_message() {
        let error = JohnnySonic.Error.unsupportedTimeBasis(.beat)

        #expect(error.message == "Unsupported time basis: beat")
    }
}
