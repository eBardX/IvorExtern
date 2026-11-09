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
    func handlePedal_keepsEveryEventExactly() {
        let beatMap = MIDI.BeatMap(division: .metrical(SMFTickRate(480)))
        var context = MIDI.Importer.Context(timeMap: beatMap)

        context.handlePedal(SMFEventTime(0), .sustain, MIDI.PedalValue(127))
        context.handlePedal(SMFEventTime(480), .sustain, MIDI.PedalValue(0))
        context.handlePedal(SMFEventTime(480), .sustain, MIDI.PedalValue(64))
        context.handlePedal(SMFEventTime(480), .soft, MIDI.PedalValue(127))

        #expect(context.pedals[.sustain]?.map(\.time) == [BeatTime(0), BeatTime(1), BeatTime(1)])
        #expect(context.pedals[.sustain]?.map(\.level) == [.on, .off, Pedal.Level(Number(numerator: 64, denominator: 127))])
        #expect(context.pedals[.soft]?.map(\.level) == [.on])
    }

    @Test
    func init_emptyState() {
        let beatMap = MIDI.BeatMap(division: .metrical(SMFTickRate(480)))
        let context = MIDI.Importer.Context(timeMap: beatMap)

        #expect(context.noteTable.isEmpty)
        #expect(context.dynamicMap.isEmpty)
        #expect(context.panMap.isEmpty)
        #expect(context.pedals.isEmpty)
    }
}
