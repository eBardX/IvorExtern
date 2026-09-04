// © 2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import Testing

struct GuidoImporterContextDynamicEventKindTests {
}

// MARK: -

extension GuidoImporterContextDynamicEventKindTests {
    @Test
    func equality_distinctCases() {
        #expect(Guido.Importer.Context.DynamicEvent.Kind.rampBoundary != .step)
    }

    @Test
    func equality_sameCase() {
        #expect(Guido.Importer.Context.DynamicEvent.Kind.step == .step)
    }
}
