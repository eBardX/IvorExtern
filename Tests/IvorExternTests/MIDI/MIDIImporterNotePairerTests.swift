// © 2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import IvorMIDI
import Testing
import XestiTools

struct MIDIImporterNotePairerTests {
}

// MARK: -

extension MIDIImporterNotePairerTests {
    @Test
    func ingest_nonMIDIEvent_ignored() throws {
        let t0 = SMFEventTime(0)
        let text = try #require(SMFText(stringValue: "a"))
        let sysEx = SMFSysExMessage.systemExclusive([0x7e, 0xf7])
        let channel = MIDIChannel(1)
        var pairer = MIDI.Importer.NotePairer(channel: channel)

        try pairer.ingest(.meta(t0, .marker(text)))
        try pairer.ingest(.sysEx(t0, sysEx))

        let voice = try pairer.makeVoice(name: "Test")

        #expect(voice.notes.isEmpty)
        #expect(voice.panEvents.isEmpty)
    }

    @Test
    func ingest_noteOnThenNoteOff_pairsNote() throws {
        let t0 = SMFEventTime(0)
        let t96 = SMFEventTime(96)
        let channel = MIDIChannel(1)
        let key = MIDIData1Value(0x3c)
        let noteOn = MIDIChannelMessage.noteOn(channel, key, MIDIData1Value(100))
        let noteOff = MIDIChannelMessage.noteOff(channel, key, MIDIData1Value(64))
        var pairer = MIDI.Importer.NotePairer(channel: channel)

        try pairer.ingest(.midi(t0, noteOn))
        try pairer.ingest(.midi(t96, noteOff))

        let voice = try pairer.makeVoice(name: "Test")

        #expect(voice.notes.count == 1)
        #expect(voice.notes[0].startTime == t0)
        #expect(voice.notes[0].duration == 96)
        #expect(voice.notes[0].onVelocity.uintValue == 100)
        #expect(voice.notes[0].offVelocity.uintValue == 64)
    }

    @Test
    func ingest_noteOnZeroVelocity_treatedAsNoteOff() throws {
        let t0 = SMFEventTime(0)
        let t96 = SMFEventTime(96)
        let channel = MIDIChannel(1)
        let key = MIDIData1Value(0x3c)
        let noteOn = MIDIChannelMessage.noteOn(channel, key, MIDIData1Value(100))
        let noteOnAsOff = MIDIChannelMessage.noteOn(channel, key, MIDIData1Value(0))
        var pairer = MIDI.Importer.NotePairer(channel: channel)

        try pairer.ingest(.midi(t0, noteOn))
        try pairer.ingest(.midi(t96, noteOnAsOff))

        let voice = try pairer.makeVoice(name: "Test")

        #expect(voice.notes.count == 1)
        #expect(voice.notes[0].offVelocity.uintValue == 0)
        #expect(voice.notes[0].duration == 96)
    }

    @Test
    func ingest_otherChannelMessage_ignored() throws {
        let t0 = SMFEventTime(0)
        let channel = MIDIChannel(1)
        let pitchBend = MIDIChannelMessage.pitchBendChange(channel, MIDIPitchBend(0))
        var pairer = MIDI.Importer.NotePairer(channel: channel)

        try pairer.ingest(.midi(t0, pitchBend))

        let voice = try pairer.makeVoice(name: "Test")

        #expect(voice.notes.isEmpty)
        #expect(voice.panEvents.isEmpty)
        #expect(voice.programChangeEvents.isEmpty)
    }

    @Test
    func ingest_panMSBControlChange_collected() throws {
        let t0 = SMFEventTime(0)
        let channel = MIDIChannel(1)
        let pan = MIDIChannelMessage.controlChange(channel, .panMSB, MIDIData1Value(0x60))
        var pairer = MIDI.Importer.NotePairer(channel: channel)

        try pairer.ingest(.midi(t0, pan))

        let voice = try pairer.makeVoice(name: "Test")

        #expect(voice.panEvents == [.midi(t0, pan)])
        #expect(voice.notes.isEmpty)
    }

    @Test
    func ingest_programChange_collected() throws {
        let t0 = SMFEventTime(0)
        let channel = MIDIChannel(1)
        let program = MIDIChannelMessage.programChange(channel, MIDIData1Value(40))
        var pairer = MIDI.Importer.NotePairer(channel: channel)

        try pairer.ingest(.midi(t0, program))

        let voice = try pairer.makeVoice(name: "Test")

        #expect(voice.programChangeEvents == [.midi(t0, program)])
        #expect(voice.notes.isEmpty)
    }

    @Test
    func ingest_repeatedKey_pairsFIFO() throws {
        let t0 = SMFEventTime(0)
        let t10 = SMFEventTime(10)
        let t20 = SMFEventTime(20)
        let t30 = SMFEventTime(30)
        let channel = MIDIChannel(1)
        let key = MIDIData1Value(0x3c)
        let onA = MIDIChannelMessage.noteOn(channel, key, MIDIData1Value(100))
        let onB = MIDIChannelMessage.noteOn(channel, key, MIDIData1Value(80))
        let off = MIDIChannelMessage.noteOff(channel, key, MIDIData1Value(64))
        var pairer = MIDI.Importer.NotePairer(channel: channel)

        try pairer.ingest(.midi(t0, onA))
        try pairer.ingest(.midi(t10, onB))
        try pairer.ingest(.midi(t20, off))
        try pairer.ingest(.midi(t30, off))

        let notes = try pairer.makeVoice(name: "Test").notes

        #expect(notes.count == 2)
        #expect(notes[0].startTime == t0)
        #expect(notes[0].onVelocity.uintValue == 100)
        #expect(notes[1].startTime == t10)
        #expect(notes[1].onVelocity.uintValue == 80)
    }

    @Test
    func ingest_unexpectedNoteOff_throws() {
        let t0 = SMFEventTime(0)
        let channel = MIDIChannel(1)
        let noteOff = MIDIChannelMessage.noteOff(channel, MIDIData1Value(0x3c), MIDIData1Value(64))

        #expect(throws: (any Error).self) {
            var pairer = MIDI.Importer.NotePairer(channel: channel)

            try pairer.ingest(.midi(t0, noteOff))
        }
    }

    @Test
    func makeVoice_noEvents_emptyVoice() throws {
        let channel = MIDIChannel(1)
        var pairer = MIDI.Importer.NotePairer(channel: channel)
        let voice = try pairer.makeVoice(name: "Test")

        #expect(voice.channel == channel)
        #expect(voice.name == "Test")
        #expect(voice.panEvents.isEmpty)
        #expect(voice.notes.isEmpty)
        #expect(voice.programChangeEvents.isEmpty)
    }

    @Test
    func makeVoice_notesSortedByStartTime() throws {
        let t0 = SMFEventTime(0)
        let t10 = SMFEventTime(10)
        let t20 = SMFEventTime(20)
        let t30 = SMFEventTime(30)
        let channel = MIDIChannel(1)
        let keyLate = MIDIData1Value(0x40)
        let keyEarly = MIDIData1Value(0x3c)
        let onLate = MIDIChannelMessage.noteOn(channel, keyLate, MIDIData1Value(100))
        let offLate = MIDIChannelMessage.noteOff(channel, keyLate, MIDIData1Value(64))
        let onEarly = MIDIChannelMessage.noteOn(channel, keyEarly, MIDIData1Value(100))
        let offEarly = MIDIChannelMessage.noteOff(channel, keyEarly, MIDIData1Value(64))
        var pairer = MIDI.Importer.NotePairer(channel: channel)

        // The later-starting note (key 0x40) is closed first, so it would
        // sort first if makeVoice() relied on completion order.
        try pairer.ingest(.midi(t10, onLate))
        try pairer.ingest(.midi(t20, offLate))
        try pairer.ingest(.midi(t0, onEarly))
        try pairer.ingest(.midi(t30, offEarly))

        let notes = try pairer.makeVoice(name: "Test").notes

        #expect(notes.map(\.startTime) == [t0, t10])
    }

    @Test
    func makeVoice_unpairedNoteOn_throws() {
        let t0 = SMFEventTime(0)
        let channel = MIDIChannel(1)
        let noteOn = MIDIChannelMessage.noteOn(channel, MIDIData1Value(0x3c), MIDIData1Value(100))

        #expect(throws: (any Error).self) {
            var pairer = MIDI.Importer.NotePairer(channel: channel)

            try pairer.ingest(.midi(t0, noteOn))
            _ = try pairer.makeVoice(name: "Test")
        }
    }
}
