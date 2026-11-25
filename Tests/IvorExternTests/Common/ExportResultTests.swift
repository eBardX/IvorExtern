// © 2026 John Gary Pusey (see LICENSE.md)

import Foundation
@testable import IvorExtern
import Testing

struct ExportResultTests {
}

// MARK: -

extension ExportResultTests {
    @Test
    func init_noWarnings() {
        let result = ExportResult(file: FileWrapper(regularFileWithContents: Data()),
                                  warnings: [])

        #expect(result.warnings.isEmpty)
    }

    @Test
    func init_storesFileAndWarnings() {
        let file = FileWrapper(regularFileWithContents: Data("X:1".utf8))
        let warning = ExternWarning(kind: .movedFigureAfterNote, count: 4, workIndex: 0)
        let result = ExportResult(file: file, warnings: [warning])

        #expect(result.file === file)
        #expect(result.warnings == [warning])
    }
}
