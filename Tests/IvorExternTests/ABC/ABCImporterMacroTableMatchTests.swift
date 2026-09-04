// © 2026 John Gary Pusey (see LICENSE.md)

import IvorABC
@testable import IvorExtern
import Testing

struct ABCImporterMacroTableMatchTests {
}

// MARK: -

extension ABCImporterMacroTableMatchTests {
    @Test
    func init_matchedNote_nilForStaticMacro() throws {
        let macro = try #require(ABCMacro(target: "T", replacement: "trill"))

        let match = ABC.Importer.MacroTable.Match(consumedCount: 1,
                                                  macro: macro,
                                                  matchedNote: nil)

        #expect(match.matchedNote == nil)
    }

    @Test
    func init_storesProperties() throws {
        let macro = try #require(ABCMacro(target: "T", replacement: "trill"))
        let octave = try #require(ABCPitch.Octave(uintValue: 4))
        let pitch = ABCPitch(letter: .c, accidental: .natural, octave: octave)
        let length = try #require(ABCLength(numerator: 1))
        let note = ABCNote(pitch: pitch, length: length, tie: nil)

        let match = ABC.Importer.MacroTable.Match(consumedCount: 2,
                                                  macro: macro,
                                                  matchedNote: note)

        #expect(match.consumedCount == 2)
        #expect(match.macro == macro)
        #expect(match.matchedNote == note)
    }
}
