// © 2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import IvorSMF
import IvorTiming
import Testing
import XestiNumbers
import XestiTools

struct MIDIBeatMapEntryTests {
}

// MARK: -

extension MIDIBeatMapEntryTests {
    @Test
    func init_setsProperties() {
        let entry = MIDI.BeatMap.Entry(eventTime: SMFEventTime(96),
                                       beatTime: BeatTime(2),
                                       tempo: 600_000)

        #expect(entry.eventTime == SMFEventTime(96))
        #expect(entry.beatTime == BeatTime(2))
        #expect(entry.tempo == 600_000)
    }
}
