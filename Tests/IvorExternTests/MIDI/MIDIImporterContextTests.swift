// © 2025–2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import IvorModel
import IvorSMF
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
    func handlePan_insertsPanValue() {
        let beatMap = MIDI.BeatMap(division: .metrical(SMFTickRate(480)))
        var context = MIDI.Importer.Context(timeMap: beatMap)

        context.handlePan(SMFEventTime(0), MIDI.PanValue(64), nil)

        #expect(!context.panMap.isEmpty)
    }

    @Test
    func handlePan_laterEvent_isStep() {
        let beatMap = MIDI.BeatMap(division: .metrical(SMFTickRate(480)))
        var context = MIDI.Importer.Context(timeMap: beatMap)

        context.handlePan(SMFEventTime(0), MIDI.PanValue(0), nil)

        let early = context.panMap[BeatTime(0)]

        context.handlePan(SMFEventTime(960), MIDI.PanValue(127), nil)

        let times = context.panMap.map(\.time)

        #expect(times == [BeatTime(0), BeatTime(2), BeatTime(2)])
        #expect(context.panMap[BeatTime(1)] == early)
        #expect(context.panMap[BeatTime(2)] != early)
    }

    @Test
    func init_emptyState() {
        let beatMap = MIDI.BeatMap(division: .metrical(SMFTickRate(480)))
        let context = MIDI.Importer.Context(timeMap: beatMap)

        #expect(context.noteTable.isEmpty)
        #expect(context.dynamicMap.isEmpty)
        #expect(context.panMap.isEmpty)
    }
}
