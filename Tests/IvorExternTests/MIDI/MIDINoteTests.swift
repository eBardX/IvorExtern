// © 2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import IvorMIDI
import Testing
import XestiTools

struct MIDINoteTests {
}

// MARK: -

extension MIDINoteTests {
    @Test
    func init_setsProperties() {
        let note = MIDI.Note(duration: 96,
                             key: MIDIData1Value(0x3c),
                             offVelocity: MIDIData1Value(64),
                             onVelocity: MIDIData1Value(100),
                             startTime: SMFEventTime(0))

        #expect(note.duration == 96)
        #expect(note.key == MIDIData1Value(0x3c))
        #expect(note.offVelocity == MIDIData1Value(64))
        #expect(note.onVelocity == MIDIData1Value(100))
        #expect(note.startTime == SMFEventTime(0))
    }
}
