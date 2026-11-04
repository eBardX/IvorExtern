// © 2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import IvorMXL
import Testing

struct MusicXMLImporterWalkerExpansionPlanTests {
}

// MARK: -

extension MusicXMLImporterWalkerExpansionPlanTests {
    @Test
    func items_carriesItsItems() {
        let plan = MusicXML.Importer.Walker.Expansion.Plan.items([])

        guard case let .items(items) = plan
        else { Issue.record("Expected .items"); return }

        #expect(items.isEmpty)
    }

    @Test
    func syntheticRest() {
        let plan = MusicXML.Importer.Walker.Expansion.Plan.syntheticRest

        guard case .syntheticRest = plan
        else { Issue.record("Expected .syntheticRest"); return }
    }
}
