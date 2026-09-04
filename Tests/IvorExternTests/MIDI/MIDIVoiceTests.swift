// © 2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import IvorMIDI
import Testing
import XestiTools

struct MIDIVoiceTests {
}

// MARK: -

extension MIDIVoiceTests {
    @Test
    func init_emptyCollections() {
        let channel = MIDIChannel(1)
        let voice = MIDI.Voice(channel: channel,
                               name: "",
                               notes: [],
                               panEvents: [],
                               programChangeEvents: [])

        #expect(voice.notes.isEmpty)
        #expect(voice.panEvents.isEmpty)
        #expect(voice.programChangeEvents.isEmpty)
    }

    @Test
    func init_setsProperties() {
        let channel = MIDIChannel(1)
        let note = MIDI.Note(duration: 96,
                             key: MIDIData1Value(0x3c),
                             offVelocity: MIDIData1Value(64),
                             onVelocity: MIDIData1Value(100),
                             startTime: SMFEventTime(0))
        let pan = MIDIChannelMessage.controlChange(channel, .panMSB, MIDIData1Value(0x60))
        let panEvent = SMFEvent.midi(SMFEventTime(0), pan)
        let program = MIDIChannelMessage.programChange(channel, MIDIData1Value(40))
        let programChangeEvent = SMFEvent.midi(SMFEventTime(0), program)
        let voice = MIDI.Voice(channel: channel,
                               name: "Right Hand",
                               notes: [note],
                               panEvents: [panEvent],
                               programChangeEvents: [programChangeEvent])

        #expect(voice.channel == channel)
        #expect(voice.name == "Right Hand")
        #expect(voice.notes.count == 1)
        #expect(voice.notes[0].startTime == note.startTime)
        #expect(voice.panEvents == [panEvent])
        #expect(voice.programChangeEvents == [programChangeEvent])
    }
}
