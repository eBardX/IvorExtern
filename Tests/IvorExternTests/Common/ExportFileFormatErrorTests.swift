// © 2026 John Gary Pusey (see LICENSE.md)

import IvorExtern
import Testing
import XestiTools

struct ExportFileFormatErrorTests {
}

// MARK: -

extension ExportFileFormatErrorTests {
    @Test
    func category() {
        #expect(ExportFileFormat.Error.writeFailure(nil).category?.stringValue == "IvorExtern")
    }

    @Test
    func writeFailure_cause() {
        let underlying = ExportFileFormat.Error.writeFailure(nil)

        #expect(ExportFileFormat.Error.writeFailure(underlying).cause?.message == underlying.message)
    }

    @Test
    func writeFailure_causeWithoutUnderlyingError() {
        #expect(ExportFileFormat.Error.writeFailure(nil).cause == nil)
    }

    @Test
    func writeFailure_message() {
        let error = ExportFileFormat.Error.writeFailure(nil)

        #expect(error.message == "Unable to write works to file")
    }
}
