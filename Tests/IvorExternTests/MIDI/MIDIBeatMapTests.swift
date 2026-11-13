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
        let timeCode = try #require(SMFTimeCode(frameRate: .fps25, ticksPerFrame: 40))
        var beatMap = MIDI.BeatMap(division: .timeCode(timeCode))

        try beatMap.append(eventTime: SMFEventTime(480), tempo: 500_000)

        #expect(throws: (any Error).self) {
            try beatMap.append(eventTime: SMFEventTime(240), tempo: 500_000)
        }
    }

    @Test
    func append_tempo_metrical_hasNoEffect() throws {
        var beatMap = MIDI.BeatMap(division: .metrical(SMFTickRate(480)))

        try beatMap.append(eventTime: SMFEventTime(240), tempo: 1_000_000)

        // 480 ticks is one quarter note.
        #expect(beatMap[SMFEventTime(480)] == BeatTime(Number(numerator: 1, denominator: 4)))
    }

    @Test
    func append_tempo_timeCode() throws {
        let timeCode = try #require(SMFTimeCode(frameRate: .fps25, ticksPerFrame: 40))
        var beatMap = MIDI.BeatMap(division: .timeCode(timeCode))

        // 1,000 ticks per second: two quarter notes per second until tick
        // 1,000, then one.
        try beatMap.append(eventTime: SMFEventTime(1_000), tempo: 1_000_000)

        #expect(beatMap[SMFEventTime(1_000)] == BeatTime(Number(numerator: 1, denominator: 2)))
        #expect(beatMap[SMFEventTime(2_000)] == BeatTime(Number(numerator: 3, denominator: 4)))
        #expect(beatMap[SMFEventTime(2_500)] == BeatTime(Number(numerator: 7, denominator: 8)))
    }

    @Test
    func append_zeroTempo_timeCode_throws() throws {
        let timeCode = try #require(SMFTimeCode(frameRate: .fps25, ticksPerFrame: 40))
        var beatMap = MIDI.BeatMap(division: .timeCode(timeCode))

        #expect(throws: (any Error).self) {
            try beatMap.append(eventTime: SMFEventTime(480), tempo: 0)
        }
    }

    @Test
    func init_metrical() {
        _ = MIDI.BeatMap(division: .metrical(SMFTickRate(480)))
    }

    @Test
    func init_timeCode() throws {
        let timeCode = try #require(SMFTimeCode(frameRate: .fps25, ticksPerFrame: 40))
        let beatMap = MIDI.BeatMap(division: .timeCode(timeCode))

        // 1,000 ticks per second at the default ♩ = 120 is 500 ticks per
        // quarter note.
        #expect(beatMap[SMFEventTime(500)] == BeatTime(Number(numerator: 1, denominator: 4)))
        #expect(beatMap[SMFEventTime(1_000)] == BeatTime(Number(numerator: 1, denominator: 2)))
    }

    @Test
    func init_timeCode_dropFrame() throws {
        let timeCode = try #require(SMFTimeCode(frameRate: .fps2997Drop, ticksPerFrame: 4))
        let beatMap = MIDI.BeatMap(division: .timeCode(timeCode))

        // 120 ticks at 30000/1001 × 4 ticks per second is exactly 1.001
        // seconds: 2.002 quarter notes.
        #expect(beatMap[SMFEventTime(120)] == BeatTime(Number(numerator: 1_001, denominator: 2_000)))
    }

    @Test
    func subscript_atZero() {
        let beatMap = MIDI.BeatMap(division: .metrical(SMFTickRate(480)))

        #expect(beatMap[SMFEventTime.zero] == .zero)
    }

    @Test
    func subscript_metrical_countsWholeNotes() {
        let beatMap = MIDI.BeatMap(division: .metrical(SMFTickRate(480)))

        // Four quarter notes of 480 ticks make a whole note.
        #expect(beatMap[SMFEventTime(480)] == BeatTime(Number(numerator: 1, denominator: 4)))
        #expect(beatMap[SMFEventTime(1_920)] == BeatTime(1))
    }
}
