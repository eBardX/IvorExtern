// © 2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import IvorModel
import IvorTiming
import IvorTuning
import Testing

struct ImportResultTests {
}

// MARK: -

extension ImportResultTests {
    @Test
    func init_empty() {
        let result = ImportResult(works: [], warnings: [])

        #expect(result.warnings.isEmpty)
        #expect(result.works.isEmpty)
    }

    @Test
    func init_storesWorksAndWarnings() {
        let warning = ExternWarning(kind: .droppedCaesura, count: 1, workIndex: 0)
        let result = ImportResult(works: [emptyWork(.beat, .standard), emptyWork(.wall, .keyboard)],
                                  warnings: [warning])

        #expect(result.warnings == [warning])
        #expect(result.works.count == 2)
    }
}
