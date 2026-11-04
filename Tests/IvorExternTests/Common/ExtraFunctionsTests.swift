// © 2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import IvorModel
import Testing
import XestiTools

struct ExtraFunctionsTests {
}

// MARK: -

extension ExtraFunctionsTests {
    @Test
    func doubleValue_doublePayload() {
        let extras = Extras(elements: [Extra(name: Extra.midiPan.name, values: [.double(0.5)])])

        #expect(doubleValue(extras, .midiPan) == 0.5)
    }

    @Test
    func doubleValue_otherPayload_isNil() {
        let extras = Extras(elements: [Extra(name: Extra.midiPan.name, values: [.int(8_192)])])

        #expect(doubleValue(extras, .midiPan) == nil)
    }

    @Test
    func hasFlag_missingName_isFalse() {
        let extras = Extras(elements: [Extra(name: Extra.accent.name, values: [])])

        #expect(!hasFlag(extras, .staccato))
        #expect(!hasFlag(nil, .accent))
    }

    @Test
    func hasFlag_presentName_isTrue() {
        let extras = Extras(elements: [Extra(name: Extra.accent.name, values: []),
                                       Extra(name: Extra.midiPan.name, values: [.int(8_192)])])

        #expect(hasFlag(extras, .accent))
        #expect(hasFlag(extras, .midiPan))
    }

    @Test
    func intValue_intPayload() {
        let extras = Extras(elements: [Extra(name: Extra.midiPan.name, values: [.int(8_192)])])

        #expect(intValue(extras, .midiPan) == 8_192)
    }

    @Test
    func intValue_missingName_isNil() {
        let extras = Extras(elements: [Extra(name: Extra.accent.name, values: [])])

        #expect(intValue(extras, .midiPan) == nil)
        #expect(intValue(nil, .midiPan) == nil)
    }

    @Test
    func stringValue_bareFlag_isNil() {
        let extras = Extras(elements: [Extra(name: Extra.instrumentName.name, values: [])])

        #expect(stringValue(extras, .instrumentName) == nil)
    }

    @Test
    func stringValue_stringPayload() {
        let extras = Extras(elements: [Extra(name: Extra.instrumentName.name, values: [.string("Flauto 1")])])

        #expect(stringValue(extras, .instrumentName) == "Flauto 1")
    }
}
