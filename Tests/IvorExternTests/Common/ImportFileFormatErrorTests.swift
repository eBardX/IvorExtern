// © 2026 John Gary Pusey (see LICENSE.md)

import IvorExtern
import Testing
import XestiTools

struct ImportFileFormatErrorTests {
}

// MARK: -

extension ImportFileFormatErrorTests {
    @Test
    func readFailure_message() {
        let error = ImportFileFormat.Error.readFailure(nil)

        #expect(error.message == "Unable to read works from file")
    }
}
