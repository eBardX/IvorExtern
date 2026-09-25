// © 2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import IvorMIDI
import IvorSMF
import Testing
import XestiTools

struct MIDIVoiceTests {
}

// MARK: -

extension MIDIVoiceTests {
    @Test
    func init_emptyCollections() {
        let channel = MIDIChannel(1)
        let voice = MIDI.Voice(bankSelectEvents: [],
                               channel: channel,
                               expressionEvents: [],
                               name: "",
                               notes: [],
                               panEvents: [],
                               programChangeEvents: [],
                               volumeEvents: [])

        #expect(voice.bankSelectEvents.isEmpty)
        #expect(voice.expressionEvents.isEmpty)
        #expect(voice.notes.isEmpty)
        #expect(voice.panEvents.isEmpty)
        #expect(voice.programChangeEvents.isEmpty)
        #expect(voice.volumeEvents.isEmpty)
    }

    @Test
    func init_setsProperties() {
        let channel = MIDIChannel(1)
        let note = MIDI.Note(duration: 96,
                             key: MIDIData1Value(0x3c),
                             offVelocity: MIDIData1Value(64),
                             onVelocity: MIDIData1Value(100),
                             peakKeyPressure: nil,
                             startTime: SMFEventTime(0))
        let pan = MIDIChannelMessage.controlChange(channel, .panMSB, MIDIData1Value(0x60))
        let panEvent = SMFEvent.midi(SMFEventTime(0), pan)
        let program = MIDIChannelMessage.programChange(channel, MIDIData1Value(40))
        let programChangeEvent = SMFEvent.midi(SMFEventTime(0), program)
        let bank = MIDIChannelMessage.controlChange(channel, .bankSelectMSB, MIDIData1Value(1))
        let bankSelectEvent = SMFEvent.midi(SMFEventTime(0), bank)
        let expression = MIDIChannelMessage.controlChange(channel, .expressionControllerMSB, MIDIData1Value(100))
        let expressionEvent = SMFEvent.midi(SMFEventTime(0), expression)
        let volume = MIDIChannelMessage.controlChange(channel, .channelVolumeMSB, MIDIData1Value(90))
        let volumeEvent = SMFEvent.midi(SMFEventTime(0), volume)
        let voice = MIDI.Voice(bankSelectEvents: [bankSelectEvent],
                               channel: channel,
                               expressionEvents: [expressionEvent],
                               name: "Right Hand",
                               notes: [note],
                               panEvents: [panEvent],
                               programChangeEvents: [programChangeEvent],
                               volumeEvents: [volumeEvent])

        #expect(voice.bankSelectEvents == [bankSelectEvent])
        #expect(voice.channel == channel)
        #expect(voice.expressionEvents == [expressionEvent])
        #expect(voice.name == "Right Hand")
        #expect(voice.notes.count == 1)
        #expect(voice.notes[0].startTime == note.startTime)
        #expect(voice.panEvents == [panEvent])
        #expect(voice.programChangeEvents == [programChangeEvent])
        #expect(voice.volumeEvents == [volumeEvent])
    }
}
