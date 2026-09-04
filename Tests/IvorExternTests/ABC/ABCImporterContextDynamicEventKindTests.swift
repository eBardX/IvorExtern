// © 2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import Testing

struct ABCImporterContextDynamicEventKindTests {
}

// MARK: -

extension ABCImporterContextDynamicEventKindTests {
    @Test
    func equality_distinctCases() {
        #expect(ABC.Importer.Context.DynamicEvent.Kind.rampBoundary != .step)
    }

    @Test
    func equality_sameCase() {
        #expect(ABC.Importer.Context.DynamicEvent.Kind.step == .step)
    }
}
