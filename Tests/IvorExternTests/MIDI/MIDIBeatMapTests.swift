// © 2025–2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import IvorMIDI
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
    func init_timeCode_throws() throws {
        let timeCode = try #require(SMPTETimeCode(frameRate: .fps24, tickRate: 40))

        #expect(throws: (any Error).self) {
            try MIDI.BeatMap(division: .timeCode(timeCode))
        }
    }

    @Test
    func subscript_atZero() throws {
        let beatMap = try MIDI.BeatMap(division: .metrical(SMFTickRate(480)))
        let (beatTime, _) = beatMap[SMFEventTime.zero]

        #expect(beatTime == .zero)
    }
}
