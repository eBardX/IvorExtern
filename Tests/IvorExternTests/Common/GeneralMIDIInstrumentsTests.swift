// © 2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import Testing

struct GeneralMIDIInstrumentsTests {
}

// MARK: -

extension GeneralMIDIInstrumentsTests {
    @Test
    func generalMIDIInstrumentName_lastProgram_returnsGunshot() {
        #expect(generalMIDIInstrumentName(program: 127) == "Gunshot")
    }

    @Test
    func generalMIDIInstrumentName_negativeProgram_returnsFallback() {
        #expect(generalMIDIInstrumentName(program: -1) == "Program -1")
    }

    @Test
    func generalMIDIInstrumentName_outOfRangeProgram_returnsFallback() {
        #expect(generalMIDIInstrumentName(program: 128) == "Program 128")
    }

    @Test
    func generalMIDIInstrumentName_zeroProgram_returnsAcousticGrandPiano() {
        #expect(generalMIDIInstrumentName(program: 0) == "Acoustic Grand Piano")
    }
}
