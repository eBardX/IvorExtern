// © 2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import IvorSMF
import IvorSMPTE
import IvorTiming
import Testing
import XestiTools

struct MIDIWallTickMapTests {
}

// MARK: -

extension MIDIWallTickMapTests {
    @Test
    func releaseTime_zeroDuration_throws() throws {
        let timeCode = try #require(SMFTimeCode(frameRate: .fps25, ticksPerFrame: 40))
        let tickMap = MIDI.WallTickMap(timeCode: timeCode)

        #expect(throws: MIDI.Error.self) {
            try tickMap.releaseTime(attack: .zero, duration: .zero)
        }
    }

    @Test
    func subscript_dropFrame_roundsToNearestTick() throws {
        let timeCode = try #require(SMFTimeCode(frameRate: .fps2997Drop, ticksPerFrame: 4))
        let tickMap = MIDI.WallTickMap(timeCode: timeCode)

        // One second is 119.88 ticks.
        #expect(tickMap[WallTime(1_000_000)] == SMFEventTime(120))
    }

    @Test
    func subscript_invertsWallMap() throws {
        let timeCode = try #require(SMFTimeCode(frameRate: .fps2997Drop, ticksPerFrame: 80))
        let wallMap = MIDI.WallMap(timeCode: timeCode)
        let tickMap = MIDI.WallTickMap(timeCode: timeCode)

        for ticks in [UInt(0), 1, 1_234, 24_000, 99_999] {
            #expect(tickMap[wallMap[SMFEventTime(ticks)]] == SMFEventTime(ticks))
        }
    }
}
