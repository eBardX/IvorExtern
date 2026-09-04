// © 2026 John Gary Pusey (see LICENSE.md)

import IvorExtern
import Testing
import XestiTools

struct ExportFileFormatErrorTests {
}

// MARK: -

extension ExportFileFormatErrorTests {
    @Test
    func writeFailure_message() {
        let error = ExportFileFormat.Error.writeFailure(nil)

        #expect(error.message == "Unable to write works to file")
    }
}
