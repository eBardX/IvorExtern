// © 2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import Testing

struct MusicXMLImporterContextDynamicEventKindTests {
}

// MARK: -

extension MusicXMLImporterContextDynamicEventKindTests {
    @Test
    func equality_distinctCases() {
        #expect(MusicXML.Importer.Context.DynamicEvent.Kind.rampBoundary != .step)
    }

    @Test
    func equality_sameCase() {
        #expect(MusicXML.Importer.Context.DynamicEvent.Kind.step == .step)
    }
}
