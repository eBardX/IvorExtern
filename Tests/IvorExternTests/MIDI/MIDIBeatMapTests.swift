// © 2025–2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import IvorSMF
import IvorSMPTE
import IvorTiming
import Testing
import XestiNumbers
import XestiTools

struct MIDIBeatMapTests {
}

// MARK: -

extension MIDIBeatMapTests {
    @Test
    func append_lowerEventTime_throws() throws {
        var beatMap = try MIDI.BeatMap(division: .metrical(SMFTickRate(480)))

        try beatMap.append(eventTime: SMFEventTime(480), clockRate: 24)

        #expect(throws: (any Error).self) {
            try beatMap.append(eventTime: SMFEventTime(240), clockRate: 24)
        }
    }

    @Test
    func append_zeroClockRate_throws() throws {
        var beatMap = try MIDI.BeatMap(division: .metrical(SMFTickRate(480)))

        #expect(throws: (any Error).self) {
            try beatMap.append(eventTime: SMFEventTime(480), clockRate: 0)
        }
    }

    @Test
    func init_metrical() throws {
        _ = try MIDI.BeatMap(division: .metrical(SMFTickRate(480)))
    }

    @Test
    func append_tempo_metrical_hasNoEffect() throws {
        var beatMap = try MIDI.BeatMap(division: .metrical(SMFTickRate(480)))

        try beatMap.append(eventTime: SMFEventTime(240), tempo: 1_000_000)

        let (beatTime, _) = beatMap[SMFEventTime(480)]

        #expect(beatTime == BeatTime(1))
    }

    @Test
    func append_tempo_timeCode() throws {
        let timeCode = try #require(SMFTimeCode(frameRate: .fps25, ticksPerFrame: 40))
        var beatMap = try MIDI.BeatMap(division: .timeCode(timeCode))

        // 1,000 ticks per second: two beats per second until tick 1,000, then one.
        try beatMap.append(eventTime: SMFEventTime(1_000), tempo: 1_000_000)

        #expect(beatMap[SMFEventTime(1_000)].0 == BeatTime(2))
        #expect(beatMap[SMFEventTime(2_000)].0 == BeatTime(3))
        #expect(beatMap[SMFEventTime(2_500)].0 == BeatTime(Number(numerator: 7, denominator: 2)))
    }

    @Test
    func append_tempo_timeCode_withClockRate() throws {
        let timeCode = try #require(SMFTimeCode(frameRate: .fps25, ticksPerFrame: 40))
        var beatMap = try MIDI.BeatMap(division: .timeCode(timeCode))

        // A clock rate of 12 makes the beat an eighth note.
        try beatMap.append(eventTime: .zero, clockRate: 12)
        try beatMap.append(eventTime: SMFEventTime(1_000), tempo: 250_000)

        #expect(beatMap[SMFEventTime(1_000)].0 == BeatTime(4))
        #expect(beatMap[SMFEventTime(2_000)].0 == BeatTime(12))
    }

    @Test
    func append_zeroTempo_timeCode_throws() throws {
        let timeCode = try #require(SMFTimeCode(frameRate: .fps25, ticksPerFrame: 40))
        var beatMap = try MIDI.BeatMap(division: .timeCode(timeCode))

        #expect(throws: (any Error).self) {
            try beatMap.append(eventTime: SMFEventTime(480), tempo: 0)
        }
    }

    @Test
    func init_timeCode() throws {
        let timeCode = try #require(SMFTimeCode(frameRate: .fps25, ticksPerFrame: 40))
        let beatMap = try MIDI.BeatMap(division: .timeCode(timeCode))

        // 1,000 ticks per second at the default 120 BPM is 500 ticks per beat.
        #expect(beatMap[SMFEventTime(500)].0 == BeatTime(1))
        #expect(beatMap[SMFEventTime(1_000)].0 == BeatTime(2))
    }

    @Test
    func init_timeCode_dropFrame() throws {
        let timeCode = try #require(SMFTimeCode(frameRate: .fps2997, ticksPerFrame: 4))
        let beatMap = try MIDI.BeatMap(division: .timeCode(timeCode))

        // 120 ticks at 30000/1001 × 4 ticks per second is exactly 1.001 seconds.
        #expect(beatMap[SMFEventTime(120)].0 == BeatTime(Number(numerator: 1_001, denominator: 500)))
    }

    @Test
    func init_zeroTickRate_throws() {
        #expect(throws: (any Error).self) {
            try MIDI.BeatMap(division: .metrical(SMFTickRate(0)))
        }
    }

    @Test
    func subscript_atZero() throws {
        let beatMap = try MIDI.BeatMap(division: .metrical(SMFTickRate(480)))
        let (beatTime, _) = beatMap[SMFEventTime.zero]

        #expect(beatTime == .zero)
    }

    @Test
    func subscript_pastLastEntry() throws {
        let beatMap = try MIDI.BeatMap(division: .metrical(SMFTickRate(480)))
        let (beatTime, _) = beatMap[SMFEventTime(480)]

        #expect(beatTime == BeatTime(1))
    }

    @Test
    func subscript_withDuplicateEntryAtZero() throws {
        var beatMap = try MIDI.BeatMap(division: .metrical(SMFTickRate(480)))

        try beatMap.append(eventTime: SMFEventTime.zero, clockRate: 24)

        let (beatTime, _) = beatMap[SMFEventTime(480)]

        #expect(beatTime == BeatTime(1))
    }
}
