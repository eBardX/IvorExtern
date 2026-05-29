// © 2025–2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import IvorMIDI
import Testing
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
    func parseFailure_message() {
        let error = MIDI.Error.parseFailure(nil)

        #expect(error.message == "Unable to parse SMF sequence")
    }

    @Test
    func multipleWorksNotSupported_message() {
        let error = MIDI.Error.multipleWorksNotSupported

        #expect(error.message == "Multiple works are not supported")
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
}
