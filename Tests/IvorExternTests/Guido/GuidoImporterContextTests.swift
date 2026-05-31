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
    func advance_inChord_tracksLongestDuration() {
        var context = Guido.Importer.Context()

        context.beginChord()
        context.advance(BeatDuration(2))
        context.advance(BeatDuration(1))

        #expect(context.currentBeatTime == .zero)
        #expect(context.chordBeatDuration == BeatDuration(2))
    }

    @Test
    func advance_notInChord_incrementsCurrentBeatTime() {
        var context = Guido.Importer.Context()

        context.advance(BeatDuration(1))

        #expect(context.currentBeatTime == BeatTime(1))
    }

    @Test
    func beginChord_setsInChord() {
        var context = Guido.Importer.Context()

        context.beginChord()

        #expect(context.inChord)
        #expect(context.chordBeatDuration == .zero)
    }

    @Test
    func endChord_advancesTimeAndClearsChord() {
        var context = Guido.Importer.Context()

        context.beginChord()
        context.advance(BeatDuration(3))
        context.endChord()

        #expect(!context.inChord)
        #expect(context.chordBeatDuration == .zero)
        #expect(context.currentBeatTime == BeatTime(3))
    }

    @Test
    func init_defaultState() {
        let context = Guido.Importer.Context()

        #expect(context.chordBeatDuration == .zero)
        #expect(context.currentBeatTime == .zero)
        #expect(!context.inChord)
        #expect(context.noteTable.isEmpty)
    }
}
