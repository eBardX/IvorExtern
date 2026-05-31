// © 2025–2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import IvorMIDI
import IvorModel
import IvorTiming
import IvorTuning
import Testing
import XestiNumbers
import XestiTools

struct MIDIImporterContextTests {
}

// MARK: -

extension MIDIImporterContextTests {
    @Test
    func handleNoteOff_noMatchingPendingNote_doesNotInsert() throws {
        let beatMap = try MIDI.BeatMap(division: .metrical(SMFTickRate(480)))
        var context = MIDI.Importer.Context(beatMap: beatMap)

        context.handleNoteOff(SMFEventTime(480), MIDI.NoteNumber(60))

        #expect(context.noteTable.isEmpty)
    }

    @Test
    func handleNoteOn_addsPendingNote() throws {
        let beatMap = try MIDI.BeatMap(division: .metrical(SMFTickRate(480)))
        var context = MIDI.Importer.Context(beatMap: beatMap)

        context.handleNoteOn(SMFEventTime(0), MIDI.NoteNumber(60), MIDI.KeyVelocity(64))

        #expect(context.pendingNotes.count == 1)
    }

    @Test
    func handleNoteOn_thenNoteOff_insertsNote() throws {
        let beatMap = try MIDI.BeatMap(division: .metrical(SMFTickRate(480)))
        var context = MIDI.Importer.Context(beatMap: beatMap)

        context.handleNoteOn(SMFEventTime(0), MIDI.NoteNumber(60), MIDI.KeyVelocity(64))
        context.handleNoteOff(SMFEventTime(480), MIDI.NoteNumber(60))

        #expect(!context.noteTable.isEmpty)
        #expect(context.pendingNotes.isEmpty)
    }

    @Test
    func init_emptyState() throws {
        let beatMap = try MIDI.BeatMap(division: .metrical(SMFTickRate(480)))
        let context = MIDI.Importer.Context(beatMap: beatMap)

        #expect(context.partName.isEmpty)
        #expect(context.pendingNotes.isEmpty)
        #expect(context.noteTable.isEmpty)
    }
}
