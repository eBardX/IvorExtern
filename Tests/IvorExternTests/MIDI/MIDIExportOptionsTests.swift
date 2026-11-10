// © 2026 John Gary Pusey (see LICENSE.md)

import IvorExtern
import IvorSMPTE
import Testing

struct MIDIExportOptionsTests {
}

// MARK: -

extension MIDIExportOptionsTests {
    @Test
    func init_defaults() {
        let options = MIDIExportOptions()

        #expect(options.ticksPerFrame == 40)
        #expect(options.ticksPerQuarterNote == 480)
        #expect(options.timeCodeFrameRate == .fps25)
    }

    @Test
    func ranges() {
        #expect(MIDIExportOptions.ticksPerFrameRange == 1...255)
        #expect(MIDIExportOptions.ticksPerQuarterNoteRange == 1...32_767)
    }

    @Test
    func supportedFrameRates_areSMFs() {
        #expect(MIDIExportOptions.supportedFrameRates == [.fps24, .fps25, .fps2997Drop, .fps30])
    }
}
