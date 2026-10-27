// © 2026 John Gary Pusey (see LICENSE.md)

import IvorExtern
import IvorModel
import Testing

struct PatchGeneralMIDITests {
}

// MARK: -

extension PatchGeneralMIDITests {
    @Test
    func generalMIDIName_custom_isNil() throws {
        #expect(try #require(Patch(.custom(program: 5, bank: 8, name: "Warm Pad"))).generalMIDIName == nil)
    }

    @Test
    func generalMIDIName_generalMIDI1_isInstrumentName() throws {
        #expect(try #require(Patch(.generalMIDI1(program: 20))).generalMIDIName == "Church Organ")
    }

    @Test
    func generalMIDIName_generalMIDI1Percussion_isNil() throws {
        #expect(try #require(Patch(.generalMIDI1Percussion)).generalMIDIName == nil)
    }

    @Test
    func generalMIDIName_generalMIDI2UnnamedVariation_isInstrumentName() throws {
        #expect(try #require(Patch(.generalMIDI2(program: 20, variation: 127))).generalMIDIName == "Church Organ")
    }

    @Test
    func generalMIDIName_generalMIDI2Variation_isVariationName() throws {
        let name = try #require(Patch(.generalMIDI2(program: 20, variation: 1))).generalMIDIName

        #expect(name != nil)
        #expect(name != "Church Organ")
    }

    @Test
    func generalMIDIName_generalMIDI2DrumSet_isDrumSetName() throws {
        #expect(try #require(Patch(.generalMIDI2DrumSet(program: 1))).generalMIDIName == "Standard Set")
    }

    @Test
    func generalMIDIName_generalMIDI2NonstandardDrumSet_isNil() throws {
        #expect(try #require(Patch(.generalMIDI2DrumSet(program: 2))).generalMIDIName == nil)
    }

    @Test
    func instrumentGeneralMIDIInstrument_matchesByName() throws {
        #expect(try #require(Instrument(stringValue: "Church Organ")).generalMIDIInstrument != nil)
        #expect(try #require(Instrument(stringValue: "Theremin Ensemble")).generalMIDIInstrument == nil)
    }
}
