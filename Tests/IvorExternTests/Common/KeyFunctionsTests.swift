// © 2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import IvorModel
import IvorTiming
import IvorTuning
import Testing
import XestiNumbers
import XestiTools

struct KeyFunctionsTests {
}

// MARK: -

extension KeyFunctionsTests {
    @Test
    func accidental_forLetter() throws {
        let twoFlats = try key(-2, .major)

        #expect(accidental(for: .b, in: twoFlats) == .flat)
        #expect(accidental(for: .e, in: twoFlats) == .flat)
        #expect(accidental(for: .a, in: twoFlats) == .natural)
        #expect(try accidental(for: .f, in: customKey([.bFlat, .fSharp])) == .sharp)
        #expect(accidental(for: .f, in: .atonal) == .natural)
        #expect(accidental(for: .f, in: nil) == .natural)
    }

    @Test
    func foldedFifths_foldsPastSeven() {
        #expect(foldedFifths(3) == 3)
        #expect(foldedFifths(8) == -4)
        #expect(foldedFifths(-9) == 3)
        #expect(foldedFifths(7) == 7)
        #expect(foldedFifths(-7) == -7)
    }

    @Test
    func makeKeyTable_dropsRepeats() throws {
        let table = try makeKeyTable([(0, key(2, .major)),
                                      (1, key(2, .major)),     // repeat: dropped
                                      (2, key(2, .minor)),     // mode change: kept
                                      (3, customKey([.fSharp, .gSharp])),
                                      (3, key(-1)),            // same time: later wins
                                      (4, key(-1)),            // repeat: dropped
                                      (5, .atonal),
                                      (6, .atonal)])           // repeat: dropped

        #expect(keySummary(table) == ["0 D major", "2 B minor", "3 Bb", "5 Atonal"])
    }

    @Test
    func makeKeyTable_noModeDiffersFromMode() throws {
        let table = try makeKeyTable([(0, key(0)),
                                      (1, key(0, .major))])

        #expect(keySummary(table) == ["0 (no accidentals)", "1 C major"])
    }

    @Test
    func writtenTonic_byMode() throws {
        #expect(try writtenTonic(of: key(2)) == .d)
        #expect(try writtenTonic(of: key(2, .major)) == .d)
        #expect(try writtenTonic(of: key(2, .minor)) == .b)
        #expect(try writtenTonic(of: key(2, .dorian)) == .e)
        #expect(try writtenTonic(of: key(2, .lydian)) == .g)
        #expect(try writtenTonic(of: key(2, .locrian)) == .cSharp)
        #expect(try writtenTonic(of: customKey([.bFlat, .fSharp])) == nil)
        #expect(writtenTonic(of: .atonal) == nil)
    }
}
