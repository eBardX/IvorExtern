// © 2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import IvorSMF
import IvorSMPTE
import IvorTiming
import Testing
import XestiTools

struct MIDIWallMapTests {
}

// MARK: -

extension MIDIWallMapTests {
    @Test
    func subscript_dropFrame_roundsToNearestMicrosecond() throws {
        let timeCode = try #require(SMFTimeCode(frameRate: .fps2997Drop, ticksPerFrame: 80))
        let wallMap = MIDI.WallMap(timeCode: timeCode)

        // Tick 24,000 is frame 300: 300 × 1.001 / 30 = 10.01 seconds.
        #expect(wallMap[SMFEventTime(24_000)] == WallTime(10_010_000))
    }

    @Test
    func timeSpan() throws {
        let timeCode = try #require(SMFTimeCode(frameRate: .fps25, ticksPerFrame: 40))
        let wallMap = MIDI.WallMap(timeCode: timeCode)
        let (attack, duration) = wallMap.timeSpan(at: SMFEventTime(250),
                                                  ticks: 1_500)

        #expect(attack == WallTime(250_000))
        #expect(duration == WallDuration(1_500_000))
    }
}
