// © 2025–2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import IvorModel
import IvorTiming
import Testing
import XestiNumbers

struct MusicXMLImporterContextTests {
}

// MARK: -

extension MusicXMLImporterContextTests {
    @Test
    func emitNoteInProgress_noPitch_resetsStateAndAdvancesTime() {
        var context = MusicXML.Importer.Context()

        context.currentBeatDuration = BeatDuration(2)
        context.noteInProgress = true

        context.emitNoteInProgress()

        #expect(!context.noteInProgress)
        #expect(context.currentBeatDuration == .zero)
        #expect(context.currentBeatTime == BeatTime(2))
        #expect(context.noteTable.isEmpty)
    }

    @Test
    func emitNoteInProgress_notInProgress_doesNothing() {
        var context = MusicXML.Importer.Context()

        context.emitNoteInProgress()

        #expect(!context.noteInProgress)
        #expect(context.currentBeatTime == .zero)
        #expect(context.noteTable.isEmpty)
    }

    @Test
    func init_defaultState() {
        let context = MusicXML.Importer.Context()

        #expect(context.currentBeatDuration == .zero)
        #expect(context.currentBeatTime == .zero)
        #expect(context.currentDivisions == 1)
        #expect(context.currentStandardPitch == nil)
        #expect(!context.isChord)
        #expect(!context.noteInProgress)
        #expect(context.noteTable.isEmpty)
        #expect(context.previousBeatTime == .zero)
    }

    @Test
    func makeBeatDuration_oneBeatPerDivision() {
        let context = MusicXML.Importer.Context()

        #expect(context.makeBeatDuration(1) == BeatDuration(1))
    }

    @Test
    func makeBeatDuration_scalesByDivisions() {
        var context = MusicXML.Importer.Context()

        context.currentDivisions = 2

        #expect(context.makeBeatDuration(2) == BeatDuration(1))
        #expect(context.makeBeatDuration(4) == BeatDuration(2))
    }
}
