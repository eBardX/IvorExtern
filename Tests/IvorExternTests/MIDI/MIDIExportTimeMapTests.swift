// © 2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import IvorSMF
import IvorSMPTE
import IvorTiming
import Testing
import XestiNumbers
import XestiTools

struct MIDIExportTimeMapTests {
}

// MARK: -

extension MIDIExportTimeMapTests {
    @Test
    func eventTime_tickMap_matchesSubscript() {
        let tickMap = MIDI.TickMap(tickRate: SMFTickRate(480))

        #expect(tickMap.eventTime(at: beat(1, 2)) == SMFEventTime(960))
        #expect(tickMap.eventTime(at: BeatTime(2)) == tickMap[BeatTime(2)])
    }

    @Test
    func eventTime_wallTickMap_matchesSubscript() throws {
        let timeCode = try #require(SMFTimeCode(frameRate: .fps25, ticksPerFrame: 40))
        let tickMap = MIDI.WallTickMap(timeCode: timeCode)

        #expect(tickMap.eventTime(at: WallTime(1_000_000)) == SMFEventTime(1_000))
    }

    @Test
    func releaseTime_tickMap_addsDuration() throws {
        let tickMap = MIDI.TickMap(tickRate: SMFTickRate(480))
        let release = try tickMap.releaseTime(attack: BeatTime(1),
                                              duration: BeatDuration(Number(numerator: 1, denominator: 2)))

        #expect(release == BeatTime(Number(numerator: 3, denominator: 2)))
    }

    @Test
    func releaseTime_tickMap_zeroDuration_throws() {
        let tickMap = MIDI.TickMap(tickRate: SMFTickRate(480))

        #expect(throws: MIDI.Error.self) {
            try tickMap.releaseTime(attack: .zero, duration: BeatDuration(0))
        }
    }

    @Test
    func releaseTime_wallTickMap_addsDuration() throws {
        let timeCode = try #require(SMFTimeCode(frameRate: .fps25, ticksPerFrame: 40))
        let tickMap = MIDI.WallTickMap(timeCode: timeCode)
        let release = try tickMap.releaseTime(attack: WallTime(1_000_000),
                                              duration: WallTime(500_000) - WallTime.zero)

        #expect(release == WallTime(1_500_000))
    }
}
