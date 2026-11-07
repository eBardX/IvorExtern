// © 2026 John Gary Pusey (see LICENSE.md)

import IvorABC
@testable import IvorExtern
import Testing

struct ABCImporterMacroTableTests {
    private let macroTable = ABC.Importer.MacroTable()
}

// MARK: -

extension ABCImporterMacroTableTests {
    @Test
    func expand_staticMacro_returnsReplacementSymbols() throws {
        let macro = try #require(ABCMacro(target: "T", replacement: "GA"))
        let match = ABC.Importer.MacroTable.Match(consumedCount: 1,
                                                  macro: macro,
                                                  matchedNote: nil)

        let symbols = try macroTable.expand(match)

        #expect(try symbols == abcSymbols(from: "GA"))
    }

    @Test
    func expand_throwsWhenTranspositionOutOfRange() throws {
        let macro = try #require(ABCMacro(target: "Tn", replacement: "h"))
        let octave = try #require(ABCPitch.Octave(uintValue: 0))
        let pitch = ABCPitch(letter: .c, accidental: .natural, octave: octave)
        let length = try #require(ABCLength(numerator: 1))
        let note = ABCNote(pitch: pitch, length: length, tie: nil)
        let match = ABC.Importer.MacroTable.Match(consumedCount: 1,
                                                  macro: macro,
                                                  matchedNote: note)

        #expect(throws: ABC.Error.self) {
            try macroTable.expand(match)
        }
    }

    @Test(arguments: [("[CE]n", "[CE]C"),
                      ("An", "AC"),
                      ("n2", "C2"),
                      ("{g}n", "{g}C")])
    func expand_transposingMacro_copiesEverythingButPlaceholders(replacement: String, expected: String) throws {
        let symbols = try macroTable.expand(makeABCMacroMatch(replacement: replacement))

        #expect(try symbols == abcSymbols(from: expected))
    }

    @Test
    func expand_transposingMacro_leavesDecorationsVerbatim() throws {
        let symbols = try macroTable.expand(makeABCMacroMatch(replacement: "!p!n"))

        #expect(try symbols == abcSymbols(from: "!p!C"))
    }

    @Test
    func expand_transposingMacro_matchedNote_substitutesPitch() throws {
        let macro = try #require(ABCMacro(target: "Tn", replacement: "o"))
        let octave = try #require(ABCPitch.Octave(uintValue: 4))
        let pitch = ABCPitch(letter: .c, accidental: .natural, octave: octave)
        let length = try #require(ABCLength(numerator: 1))
        let note = ABCNote(pitch: pitch, length: length, tie: nil)
        let match = ABC.Importer.MacroTable.Match(consumedCount: 1,
                                                  macro: macro,
                                                  matchedNote: note)

        let symbols = try macroTable.expand(match)

        #expect(try symbols == abcSymbols(from: "D"))
    }

    @Test
    func expand_transposingMacro_noMatchedNote_returnsEmpty() throws {
        let macro = try #require(ABCMacro(target: "Tn", replacement: "n"))
        let match = ABC.Importer.MacroTable.Match(consumedCount: 1,
                                                  macro: macro,
                                                  matchedNote: nil)

        let symbols = try macroTable.expand(match)

        #expect(symbols.isEmpty)
    }

    @Test
    func findMatch_emptyMacros_returnsNil() throws {
        let symbols = try abcSymbols(from: "C D")

        let match = macroTable.findMatch(symbols, 0, [])

        #expect(match == nil)
    }

    @Test
    func findMatch_prefersMostRecentlyDefinedMacro() throws {
        let macro1 = try #require(ABCMacro(target: "G", replacement: "A"))
        let macro2 = try #require(ABCMacro(target: "G", replacement: "B"))
        let symbols = try abcSymbols(from: "G")

        let match = try #require(macroTable.findMatch(symbols, 0, [macro1, macro2]))

        #expect(match.macro == macro2)
    }

    @Test
    func findMatch_staticMacro_matchesPrefix() throws {
        let macro = try #require(ABCMacro(target: "G", replacement: "A"))
        let symbols = try abcSymbols(from: "G A")

        let match = try #require(macroTable.findMatch(symbols, 0, [macro]))

        #expect(match.consumedCount == 1)
        #expect(match.macro == macro)
        #expect(match.matchedNote == nil)
    }

    @Test
    func findMatch_staticMacro_noPrefixMatch_returnsNil() throws {
        let macro = try #require(ABCMacro(target: "G", replacement: "A"))
        let symbols = try abcSymbols(from: "A B")

        let match = macroTable.findMatch(symbols, 0, [macro])

        #expect(match == nil)
    }

    @Test(arguments: [("Tn/", "TC/"),
                      ("Tn//", "TC//"),
                      ("Tn/4", "TC/4"),
                      ("Tn3/", "TC3/"),
                      ("Tn3/2", "TC3/2")])
    func findMatch_transposingMacro_fractionalNoteLength_matches(target: String, text: String) throws {
        let macro = try #require(ABCMacro(target: target, replacement: "n"))
        let symbols = try abcSymbols(from: text)

        #expect(macroTable.findMatch(symbols, 0, [macro])?.matchedNote != nil)
    }

    @Test(arguments: ["Tn//4", "Tn/2/"])
    func findMatch_transposingMacro_malformedNoteLength_returnsNil(target: String) throws {
        let macro = try #require(ABCMacro(target: target, replacement: "n"))
        let symbols = try abcSymbols(from: "TC/4")

        #expect(macroTable.findMatch(symbols, 0, [macro]) == nil)
    }

    @Test
    func findMatch_transposingMacro_matchesNoteAfterPrefix() throws {
        let macro = try #require(ABCMacro(target: "n2", replacement: "n"))
        let symbols = try abcSymbols(from: "G2 A")

        let match = try #require(macroTable.findMatch(symbols, 0, [macro]))

        #expect(match.consumedCount == 1)
        #expect(match.matchedNote?.pitch.letter == .g)
    }

    @Test
    func findMatch_transposingMacro_noteLengthMismatch_returnsNil() throws {
        let macro = try #require(ABCMacro(target: "n2", replacement: "n"))
        let symbols = try abcSymbols(from: "G A")

        let match = macroTable.findMatch(symbols, 0, [macro])

        #expect(match == nil)
    }
}
