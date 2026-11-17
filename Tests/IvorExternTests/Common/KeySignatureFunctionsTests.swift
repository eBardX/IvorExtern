// © 2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import IvorModel
import IvorTiming
import IvorTuning
import Testing
import XestiNumbers
import XestiTools

struct KeySignatureFunctionsTests {
}

// MARK: -

extension KeySignatureFunctionsTests {
    @Test
    func diatonicKeySignature_foldsPastSeven() throws {
        #expect(try diatonicKeySignature(fifths: 3) == keySignature(3))
        #expect(try diatonicKeySignature(fifths: 8) == keySignature(-4))
        #expect(try diatonicKeySignature(fifths: -9) == keySignature(3))
        #expect(try diatonicKeySignature(fifths: 7) == keySignature(7))
    }

    @Test
    func isMinorMode_minorAndAeolian() {
        #expect(isMinorMode("minor"))
        #expect(isMinorMode("aeolian"))
        #expect(!isMinorMode("dorian"))
        #expect(!isMinorMode(nil))
    }

    @Test
    func keySignatureModeName_knownAndUnknown() {
        #expect(keySignatureModeName("Minor") == "minor")
        #expect(keySignatureModeName("MIXOLYDIAN") == "mixolydian")
        #expect(keySignatureModeName("none") == "none")
        #expect(keySignatureModeName("exp") == nil)
        #expect(keySignatureModeName("") == nil)
    }

    @Test
    func makeKeySignatureTable_dropsRepeatsAndCustomModes() throws {
        let custom = try customKeySignature([.fSharp, .gSharp])
        let table = try makeKeySignatureTable([(0, keySignature(2), "major"),
                                               (1, keySignature(2), "major"),     // repeat: dropped
                                               (2, keySignature(2), "minor"),     // mode change: kept
                                               (3, custom, "major"),                  // custom: no mode
                                               (3, keySignature(-1), nil),        // same time: later wins
                                               (4, keySignature(-1), nil)])       // repeat: dropped

        #expect(keySummary(table) == ["0 2# major", "2 2# minor", "3 1b"])
    }

    @Test
    func makeKeySignatureTable_customKeepsNoMode() throws {
        let table = try makeKeySignatureTable([(0, customKeySignature([.bFlat, .fSharp]), "minor")])

        #expect(keySummary(table) == ["0 Bb F#"])
    }

    @Test
    func tonic_byMode() throws {
        let twoSharps = try keySignature(2)

        #expect(tonic(of: twoSharps, mode: nil) == .d)
        #expect(tonic(of: twoSharps, mode: "major") == .d)
        #expect(tonic(of: twoSharps, mode: "minor") == .b)
        #expect(tonic(of: twoSharps, mode: "aeolian") == .b)
        #expect(tonic(of: twoSharps, mode: "dorian") == .e)
        #expect(tonic(of: twoSharps, mode: "lydian") == .g)
        #expect(tonic(of: twoSharps, mode: "locrian") == .cSharp)
        #expect(tonic(of: twoSharps, mode: "none") == .d)
        #expect(try tonic(of: customKeySignature([.bFlat, .fSharp]), mode: nil) == nil)
    }
}
