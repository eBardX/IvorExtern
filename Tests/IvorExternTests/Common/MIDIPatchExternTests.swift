// © 2026 John Gary Pusey (see LICENSE.md)

import IvorExtern
import IvorMIDI
import IvorModel
import Testing
import XestiTools

struct MIDIPatchExternTests {
}

// MARK: -

extension MIDIPatchExternTests {
    @Test
    func initInstrument_matchingName_isItsProgram() throws {
        let instrument = try #require(Instrument(stringValue: "Church Organ"))

        #expect(MIDIPatch(instrument: instrument) == MIDIPatch(program: 20))
    }

    @Test
    func initInstrument_unmatchedName_isFirstProgram() throws {
        let instrument = try #require(Instrument(stringValue: "Theremin Ensemble"))

        #expect(MIDIPatch(instrument: instrument) == MIDIPatch(program: 1))
    }

    @Test
    func initPatch_custom_usesItsBank() throws {
        let patch = try MIDIPatch(patch: #require(Patch(.custom(program: 5, bank: 300, name: nil))))

        #expect(patch == MIDIPatch(program: 5, bank: MIDIBank(msb: 2, lsb: 44)))
    }

    @Test
    func initPatch_customWithoutBank_selectsNoBank() throws {
        let patch = try MIDIPatch(patch: #require(Patch(.custom(program: 5, bank: nil, name: "Lead"))))

        #expect(patch == MIDIPatch(program: 5))
    }

    @Test
    func initPatch_generalMIDI1_selectsNoBank() throws {
        let patch = try MIDIPatch(patch: #require(Patch(.generalMIDI1(program: 20))))

        #expect(patch == MIDIPatch(program: 20))
    }

    @Test
    func initPatch_generalMIDI1Percussion_isFirstProgram() throws {
        let patch = try MIDIPatch(patch: #require(Patch(.generalMIDI1Percussion)))

        #expect(patch == MIDIPatch(program: 1))
    }

    @Test
    func initPatch_generalMIDI2_selectsBank121() throws {
        let patch = try MIDIPatch(patch: #require(Patch(.generalMIDI2(program: 20, variation: 1))))

        #expect(patch == MIDIPatch(program: 20, bank: MIDIBank(msb: 121, lsb: 1)))
    }

    @Test
    func initPatch_generalMIDI2DrumSet_selectsBank120() throws {
        let patch = try MIDIPatch(patch: #require(Patch(.generalMIDI2DrumSet(program: 9))))

        #expect(patch == MIDIPatch(program: 9, bank: MIDIBank(msb: 120, lsb: 0)))
    }
}
