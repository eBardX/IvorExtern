// © 2025–2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import IvorMIDI
import IvorTiming
import IvorTuning
import Testing
import XestiNumbers
import XestiTools

struct MIDIErrorTests {
}

// MARK: -

extension MIDIErrorTests {
    @Test
    func convertFailure_message() {
        let error = MIDI.Error.convertFailure(nil)

        #expect(error.message == "Unable to convert Ivor work to SMF sequence")
    }

    @Test
    func emptyBeatMap_message() {
        let error = MIDI.Error.emptyBeatMap

        #expect(error.message == "Empty beat map")
    }

    @Test
    func formatFailure_message() {
        let error = MIDI.Error.formatFailure(nil)

        #expect(error.message == "Unable to format SMF sequence")
    }

    @Test
    func invalidBeatDuration_message() {
        let error = MIDI.Error.invalidBeatDuration(BeatDuration(1))

        #expect(error.message.hasPrefix("Invalid beat duration:"))
    }

    @Test
    func invalidClockRate_message() {
        let error = MIDI.Error.invalidClockRate(0)

        #expect(error.message == "Invalid SMF time signature clock rate: 0")
    }

    @Test
    func invalidEventTime_message() {
        let error = MIDI.Error.invalidEventTime(SMFEventTime(100))

        #expect(error.message == "Invalid SMF event time: 100")
    }

    @Test
    func invalidNoteNumber_message() throws {
        let noteNumber = try #require(NoteNumber(uintValue: 60))
        let error = MIDI.Error.invalidNoteNumber(noteNumber)

        #expect(error.message.hasPrefix("Invalid note number:"))
    }

    @Test
    func multipleWorksNotSupported_message() {
        let error = MIDI.Error.multipleWorksNotSupported

        #expect(error.message == "Multiple works are not supported")
    }

    @Test
    func noWorksToExport_message() {
        let error = MIDI.Error.noWorksToExport

        #expect(error.message == "No works to export")
    }

    @Test
    func parseFailure_message() {
        let error = MIDI.Error.parseFailure(nil)

        #expect(error.message == "Unable to parse SMF sequence")
    }

    @Test
    func tooManyParts_message() {
        let error = MIDI.Error.tooManyParts(17)

        #expect(error.message == "Too many parts to export: 17 (MIDI supports a maximum of 16 channels)")
    }

    @Test
    func unexpectedNoteOff_message() throws {
        let channel = try #require(MIDIChannel(uintValue: 1))
        let key = try #require(MIDIData1Value(uintValue: 60))
        let error = MIDI.Error.unexpectedNoteOff(channel: channel, key: key, time: SMFEventTime(0))

        #expect(error.message == "Unexpected note-off on channel 1 for key 60 at time 0 with no matching note-on")
    }

    @Test
    func unpairedNoteOn_message() throws {
        let channel = try #require(MIDIChannel(uintValue: 1))
        let key = try #require(MIDIData1Value(uintValue: 60))
        let error = MIDI.Error.unpairedNoteOn(channel: channel, key: key, time: SMFEventTime(0))

        #expect(error.message == "Unpaired note-on on channel 1 for key 60 at time 0 with no matching note-off")
    }

    @Test
    func unsupportedDivision_message() throws {
        let timeCode = try #require(SMPTETimeCode(frameRate: .fps24, tickRate: 40))
        let error = MIDI.Error.unsupportedDivision(.timeCode(timeCode))

        #expect(error.message.hasPrefix("Unsupported SMF division:"))
    }

    @Test
    func unsupportedFileFormat_message() {
        let error = MIDI.Error.unsupportedFileFormat("midi")

        #expect(error.message == "Unsupported file format: \u{2018}midi\u{2019}")
    }

    @Test
    func unsupportedPitchNotation_message() {
        let error = MIDI.Error.unsupportedPitchNotation(.absolute)

        #expect(error.message.hasPrefix("Unsupported pitch notation:"))
    }

    @Test
    func unsupportedTimeBasis_message() {
        let error = MIDI.Error.unsupportedTimeBasis(.beat)

        #expect(error.message == "Unsupported time basis: beat")
    }

    @Test
    func validationFailure_message() {
        let error = MIDI.Error.validationFailure([.invalidTrackCount(trackCount: 0,
                                                                     format: .format1)])

        #expect(error.message == "SMF sequence failed validation: The sequence has 0 track(s), which is not valid for format 1")
    }
}
