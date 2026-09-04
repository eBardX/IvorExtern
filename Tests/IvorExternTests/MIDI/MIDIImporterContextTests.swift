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
    func handlePan_insertsPanValue() throws {
        let beatMap = try MIDI.BeatMap(division: .metrical(SMFTickRate(480)))
        var context = MIDI.Importer.Context(beatMap: beatMap)

        context.handlePan(SMFEventTime(0), MIDI.PanValue(64))

        #expect(!context.panMap.isEmpty)
    }

    @Test
    func init_emptyState() throws {
        let beatMap = try MIDI.BeatMap(division: .metrical(SMFTickRate(480)))
        let context = MIDI.Importer.Context(beatMap: beatMap)

        #expect(context.noteTable.isEmpty)
        #expect(context.dynamicMap.isEmpty)
        #expect(context.panMap.isEmpty)
    }
}
