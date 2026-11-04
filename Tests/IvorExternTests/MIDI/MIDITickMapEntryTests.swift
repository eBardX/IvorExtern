// © 2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import IvorTiming
import Testing
import XestiNumbers
import XestiTools

struct MIDITickMapEntryTests {
}

// MARK: -

extension MIDITickMapEntryTests {
    @Test
    func init_storesProperties() {
        let entry = MIDI.TickMap.Entry(beatTime: BeatTime(4),
                                       seconds: Number(numerator: 3, denominator: 2),
                                       tempo: 250_000)

        #expect(entry.beatTime == BeatTime(4))
        #expect(entry.seconds == Number(numerator: 3, denominator: 2))
        #expect(entry.tempo == 250_000)
    }
}
