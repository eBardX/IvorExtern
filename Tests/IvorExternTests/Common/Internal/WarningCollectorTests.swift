// © 2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import Testing

struct WarningCollectorTests {
}

// MARK: -

extension WarningCollectorTests {
    @Test
    func warnings_countByKindAndWorkInOrder() {
        let collector = WarningCollector()

        collector.add(.splitArpeggio, workIndex: 1)
        collector.add(.droppedOrnament, workIndex: 0)
        collector.add(.droppedOrnament, count: 2, workIndex: 0)
        collector.add(.droppedCaesura, workIndex: nil)
        collector.add(.droppedSlash, count: 0, workIndex: 0)

        #expect(collector.warnings == [ExternWarning(kind: .droppedCaesura, count: 1, workIndex: nil),
                                       ExternWarning(kind: .droppedOrnament, count: 3, workIndex: 0),
                                       ExternWarning(kind: .splitArpeggio, count: 1, workIndex: 1)])
        #expect(WarningCollector().warnings.isEmpty)
    }
}
