// © 2026 John Gary Pusey (see LICENSE.md)

import IvorABC
@testable import IvorExtern
import IvorModel
import IvorTiming
import IvorTuning
import Testing
import XestiNumbers

struct ABCExporterAccidentalStateTests {
}

// MARK: -

extension ABCExporterAccidentalStateTests {
    @Test
    func abcPitch_accidentalCarriesThroughTheBar() throws {
        var state = ABC.Exporter.AccidentalState(keyTable: KeyTable())

        #expect(try state.abcPitch(for: "F#4").accidental == .sharp)
        #expect(try state.abcPitch(for: "F#4").accidental == .omitted)
    }

    @Test
    func abcPitch_accidentalInAnotherOctave_isWrittenAgain() throws {
        var state = ABC.Exporter.AccidentalState(keyTable: KeyTable())

        _ = try state.abcPitch(for: "F#4")

        #expect(try state.abcPitch(for: "F#5").accidental == .sharp)
    }

    @Test
    func abcPitch_cancelledAccidental_writesNatural() throws {
        var state = ABC.Exporter.AccidentalState(keyTable: KeyTable())

        _ = try state.abcPitch(for: "F#4")

        #expect(try state.abcPitch(for: "F4").accidental == .natural)
    }

    @Test
    func abcPitch_inKey_isBare() throws {
        var state = try ABC.Exporter.AccidentalState(keyTable: keyTable([(0, key(1, .major))]))

        #expect(try state.abcPitch(for: "F#4").accidental == .omitted)
        #expect(try state.abcPitch(for: "C4").accidental == .omitted)
    }

    @Test
    func abcPitch_noKey_naturalIsBare() throws {
        var state = ABC.Exporter.AccidentalState(keyTable: KeyTable())

        #expect(try state.abcPitch(for: "C4").accidental == .omitted)
    }

    @Test
    func abcPitch_outOfKey_writesNatural() throws {
        var state = try ABC.Exporter.AccidentalState(keyTable: keyTable([(0, key(1, .major))]))

        #expect(try state.abcPitch(for: "F4").accidental == .natural)
    }

    @Test
    func init_laterFirstEntry_startsWithNoKey() throws {
        var state = try ABC.Exporter.AccidentalState(keyTable: keyTable([(1, key(1, .major))]))

        #expect(try state.abcPitch(for: "F4").accidental == .omitted)
    }

    @Test
    func keyChangeSymbols_appliesTheNewKeyAndStartsABar() throws {
        var state = try ABC.Exporter.AccidentalState(keyTable: keyTable([(1, key(1, .major))]))

        _ = try state.abcPitch(for: "C#4")
        _ = state.keyChangeSymbols(through: beat(1))

        #expect(try state.abcPitch(for: "F#4").accidental == .omitted)
        #expect(try state.abcPitch(for: "C#4").accidental == .sharp)
    }

    @Test
    func keyChangeSymbols_beforeTheChange_isEmpty() throws {
        var state = try ABC.Exporter.AccidentalState(keyTable: keyTable([(0, key(0, .major)),
                                                                         (1, key(1, .major))]))

        #expect(state.keyChangeSymbols(through: beat(1, 2)).isEmpty)
    }

    @Test
    func keyChangeSymbols_entryAtZero_isNotRepeated() throws {
        var state = try ABC.Exporter.AccidentalState(keyTable: keyTable([(0, key(1, .major))]))

        #expect(state.keyChangeSymbols(through: beat(4)).isEmpty)
    }

    @Test
    func keyChangeSymbols_writesEachChangeOnce() throws {
        let gMajor = try key(1, .major)
        let dMajor = try key(2, .major)
        var state = try ABC.Exporter.AccidentalState(keyTable: keyTable([(0, key(0, .major)),
                                                                         (1, gMajor),
                                                                         (2, dMajor)]))

        #expect(state.keyChangeSymbols(through: beat(2)) == [.inlineField(.key(convertToABCKeySignature(gMajor))),
                                                             .inlineField(.key(convertToABCKeySignature(dMajor)))])
        #expect(state.keyChangeSymbols(through: beat(3)).isEmpty)
    }

    @Test
    func startBar_forgetsWrittenAccidentals() throws {
        var state = ABC.Exporter.AccidentalState(keyTable: KeyTable())

        _ = try state.abcPitch(for: "F#4")

        state.startBar()

        #expect(try state.abcPitch(for: "F#4").accidental == .sharp)
    }
}
