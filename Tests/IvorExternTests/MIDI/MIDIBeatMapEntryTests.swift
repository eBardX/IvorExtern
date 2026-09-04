// © 2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import IvorMIDI
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
        let factor = Number(numerator: 1, denominator: 2)
        let entry = MIDI.BeatMap.Entry(eventTime: SMFEventTime(96),
                                       beatTime: BeatTime(2),
                                       factor: factor)

        #expect(entry.eventTime == SMFEventTime(96))
        #expect(entry.beatTime == BeatTime(2))
        #expect(entry.factor == factor)
    }
}
