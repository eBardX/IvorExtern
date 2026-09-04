// © 2025–2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import IvorModel
import IvorTiming
import Testing
import XestiNumbers

struct GuidoImporterContextTests {
}

// MARK: -

extension GuidoImporterContextTests {
    @Test
    func advance_incrementsCurrentBeatTime() {
        var context = Guido.Importer.Context()

        context.advance(BeatDuration(1))

        #expect(context.currentBeatTime == BeatTime(1))
    }

    @Test
    func init_defaultState() {
        let context = Guido.Importer.Context()

        #expect(context.currentBeatTime == .zero)
        #expect(context.noteTable.isEmpty)
    }
}
