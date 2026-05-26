// © 2025–2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
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
    func unsupportedFileFormat_message() {
        let error = JohnnySonic.Error.unsupportedFileFormat("dkm")

        #expect(error.message == "Unsupported file format: \u{2018}dkm\u{2019}")
    }

    @Test
    func unsupportedWorkTimeBasis_message() {
        let error = JohnnySonic.Error.unsupportedWorkTimeBasis("ticks")

        #expect(error.message == "Unsupported Ivor work time basis: ticks")
    }
}
