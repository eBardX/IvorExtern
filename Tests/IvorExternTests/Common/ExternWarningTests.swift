// © 2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import Testing

struct ExternWarningTests {
}

// MARK: -

extension ExternWarningTests {
    @Test
    func equality() {
        let first = ExternWarning(kind: .droppedSlash, count: 2, workIndex: 0)
        let second = ExternWarning(kind: .droppedSlash, count: 2, workIndex: 0)

        #expect(first == second)
    }

    @Test
    func hashable() {
        let warnings: Set<ExternWarning> = [ExternWarning(kind: .droppedSlash, count: 2, workIndex: 0),
                                            ExternWarning(kind: .droppedSlash, count: 2, workIndex: 0),
                                            ExternWarning(kind: .droppedSlash, count: 2, workIndex: nil)]

        #expect(warnings.count == 2)
    }

    @Test
    func inequality_count() {
        #expect(ExternWarning(kind: .droppedSlash, count: 1, workIndex: 0)
                    != ExternWarning(kind: .droppedSlash, count: 2, workIndex: 0))
    }

    @Test
    func inequality_kind() {
        #expect(ExternWarning(kind: .droppedSlash, count: 1, workIndex: 0)
                    != ExternWarning(kind: .droppedCaesura, count: 1, workIndex: 0))
    }

    @Test
    func inequality_workIndex() {
        #expect(ExternWarning(kind: .droppedSlash, count: 1, workIndex: 0)
                    != ExternWarning(kind: .droppedSlash, count: 1, workIndex: 1))
    }

    @Test
    func init_storesValues() {
        let warning = ExternWarning(kind: .droppedFermata, count: 3, workIndex: 1)

        #expect(warning.count == 3)
        #expect(warning.kind == .droppedFermata)
        #expect(warning.workIndex == 1)
    }

    @Test
    func init_wholeFile_hasNoWorkIndex() {
        #expect(ExternWarning(kind: .droppedFermata, count: 1, workIndex: nil).workIndex == nil)
    }
}
