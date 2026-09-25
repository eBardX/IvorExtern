// © 2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import IvorSMF
import IvorSMPTE
import IvorTiming
import Testing
import XestiNumbers
import XestiTools

struct MIDITickMapTests {
}

// MARK: -

extension MIDITickMapTests {
    @Test
    func subscript_metrical() {
        let tickMap = MIDI.TickMap(tickRate: SMFTickRate(480))

        #expect(tickMap[.zero] == .zero)
        #expect(tickMap[BeatTime(Number(numerator: 3, denominator: 2))] == SMFEventTime(720))
    }

    @Test
    func subscript_timeCode_defaultTempo() throws {
        let timeCode = try #require(SMFTimeCode(frameRate: .fps25, ticksPerFrame: 40))
        let tickMap = MIDI.TickMap(timeCode: timeCode, tempoChanges: [])

        #expect(tickMap[BeatTime(2)] == SMFEventTime(1_000))
    }

    @Test
    func subscript_timeCode_dropFrame_roundsToNearestTick() throws {
        let timeCode = try #require(SMFTimeCode(frameRate: .fps2997, ticksPerFrame: 4))
        let tickMap = MIDI.TickMap(timeCode: timeCode, tempoChanges: [])

        // Two beats at 120 BPM is one second: 119.88 ticks.
        #expect(tickMap[BeatTime(2)] == SMFEventTime(120))
    }

    @Test
    func subscript_timeCode_tempoChanges() throws {
        let timeCode = try #require(SMFTimeCode(frameRate: .fps25, ticksPerFrame: 40))
        let tickMap = MIDI.TickMap(timeCode: timeCode,
                                   tempoChanges: [(BeatTime.zero, SMFTempo(250_000)),
                                                  (BeatTime(4), SMFTempo(1_000_000))])

        #expect(tickMap[BeatTime(2)] == SMFEventTime(500))
        #expect(tickMap[BeatTime(4)] == SMFEventTime(1_000))
        #expect(tickMap[BeatTime(5)] == SMFEventTime(2_000))
    }

    @Test
    func subscript_timeCode_invertsBeatMap() throws {
        let timeCode = try #require(SMFTimeCode(frameRate: .fps2997, ticksPerFrame: 80))
        var beatMap = try MIDI.BeatMap(division: .timeCode(timeCode))

        try beatMap.append(eventTime: SMFEventTime(1_234), tempo: 461_538)
        try beatMap.append(eventTime: SMFEventTime(5_678), tempo: 700_001)

        let tickMap = MIDI.TickMap(timeCode: timeCode,
                                   tempoChanges: [(BeatTime.zero, SMFTempo(500_000)),
                                                  (beatMap[SMFEventTime(1_234)].0, SMFTempo(461_538)),
                                                  (beatMap[SMFEventTime(5_678)].0, SMFTempo(700_001))])

        for ticks in stride(from: UInt(0), to: 20_000, by: 37) {
            #expect(tickMap[beatMap[SMFEventTime(ticks)].0] == SMFEventTime(ticks))
        }
    }
}
