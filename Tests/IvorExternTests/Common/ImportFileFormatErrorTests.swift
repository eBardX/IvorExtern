// © 2026 John Gary Pusey (see LICENSE.md)

import IvorExtern
import Testing
import XestiTools

struct ImportFileFormatErrorTests {
}

// MARK: -

extension ImportFileFormatErrorTests {
    @Test
    func category() {
        #expect(ImportFileFormat.Error.readFailure(nil).category?.stringValue == "IvorExtern")
    }

    @Test
    func readFailure_cause() {
        let underlying = ImportFileFormat.Error.readFailure(nil)

        #expect(ImportFileFormat.Error.readFailure(underlying).cause?.message == underlying.message)
    }

    @Test
    func readFailure_causeWithoutUnderlyingError() {
        #expect(ImportFileFormat.Error.readFailure(nil).cause == nil)
    }

    @Test
    func readFailure_message() {
        let error = ImportFileFormat.Error.readFailure(nil)

        #expect(error.message == "Unable to read works from file")
    }
}
