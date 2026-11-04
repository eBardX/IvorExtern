// © 2026 John Gary Pusey (see LICENSE.md)

import IvorExtern
import IvorGeneralMIDI
import IvorModel
import Testing
import XestiTools

struct InstrumentGeneralMIDITests {
}

// MARK: -

extension InstrumentGeneralMIDITests {
    @Test
    func generalMIDIInstrument_matchingName() throws {
        let instrument = try #require(Instrument(stringValue: "Church Organ"))
        let gmInstrument = try #require(instrument.generalMIDIInstrument)

        #expect(gmInstrument.program == 20)
        #expect(gmInstrument.name == "Church Organ")
    }

    @Test
    func generalMIDIInstrument_unmatchedName_isNil() throws {
        let instrument = try #require(Instrument(stringValue: "Theremin Ensemble"))

        #expect(instrument.generalMIDIInstrument == nil)
    }
}
