// © 2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import IvorModel
import IvorTiming
import Testing
import XestiNumbers

struct GuidoImporterContextDynamicEventTests {
}

// MARK: -

extension GuidoImporterContextDynamicEventTests {
    @Test
    func init_storesProperties() {
        let event = Guido.Importer.Context.DynamicEvent(beatTime: BeatTime(2),
                                                        dynamic: .mf,
                                                        kind: .step)

        #expect(event.beatTime == BeatTime(2))
        #expect(event.dynamic == .mf)
        #expect(event.kind == .step)
    }
}
