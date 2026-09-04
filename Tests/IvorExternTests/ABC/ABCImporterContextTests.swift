// © 2025–2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import IvorModel
import IvorTiming
import Testing
import XestiNumbers

struct ABCImporterContextTests {
}

// MARK: -

extension ABCImporterContextTests {
    @Test
    func advance_incrementsCurrentBeatTime() {
        var context = ABC.Importer.Context()

        context.advance(BeatDuration(1))

        #expect(context.currentBeatTime == BeatTime(1))
    }

    @Test
    func init_defaultState() {
        let context = ABC.Importer.Context()

        #expect(context.currentBeatTime == .zero)
        #expect(context.noteTable.isEmpty)
        #expect(context.unitNoteLength == (1, 8))
    }

    @Test
    func init_unitNoteLength_usesProvidedValue() {
        let context = ABC.Importer.Context(unitNoteLength: (1, 4))

        #expect(context.unitNoteLength == (1, 4))
    }
}
