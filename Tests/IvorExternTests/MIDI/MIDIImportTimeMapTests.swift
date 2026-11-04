// © 2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import IvorSMF
import IvorSMPTE
import IvorTiming
import Testing
import XestiNumbers
import XestiTools

struct MIDIImportTimeMapTests {
}

// MARK: -

extension MIDIImportTimeMapTests {
    @Test
    func time_beatMap_metrical() {
        let beatMap = MIDI.BeatMap(division: .metrical(SMFTickRate(480)))

        #expect(beatMap.time(at: SMFEventTime(960)) == BeatTime(2))
    }

    @Test
    func time_wallMap_timeCode() throws {
        let timeCode = try #require(SMFTimeCode(frameRate: .fps25, ticksPerFrame: 40))
        let wallMap = MIDI.WallMap(timeCode: timeCode)

        #expect(wallMap.time(at: SMFEventTime(1_000)) == WallTime(1_000_000))
    }

    @Test
    func timeSpan_beatMap_metrical() {
        let beatMap = MIDI.BeatMap(division: .metrical(SMFTickRate(480)))
        let (attack, duration) = beatMap.timeSpan(at: SMFEventTime(480),
                                                  ticks: 240)

        #expect(attack == BeatTime(1))
        #expect(duration == BeatDuration(Number(numerator: 1, denominator: 2)))
    }

    @Test
    func timeSpan_wallMap_timeCode() throws {
        let timeCode = try #require(SMFTimeCode(frameRate: .fps25, ticksPerFrame: 40))
        let wallMap = MIDI.WallMap(timeCode: timeCode)
        let (attack, duration) = wallMap.timeSpan(at: SMFEventTime(1_000),
                                                  ticks: 500)

        #expect(attack == WallTime(1_000_000))
        #expect(attack + duration == WallTime(1_500_000))
    }
}
