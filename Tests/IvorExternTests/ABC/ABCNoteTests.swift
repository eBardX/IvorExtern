// © 2026 John Gary Pusey (see LICENSE.md)

import IvorABC
@testable import IvorExtern
import Testing
import XestiNumbers

struct ABCNoteTests {
}

// MARK: -

extension ABCNoteTests {
    @Test
    func equality() throws {
        let octave = try #require(ABCPitch.Octave(uintValue: 4))
        let pitch = ABCPitch(letter: .c, accidental: .natural, octave: octave)
        let duration = ABC.Duration(numberValue: Number(numerator: 1, denominator: 4))

        let note1 = ABC.Note(duration: duration, pitch: pitch, tie: .regular)
        let note2 = ABC.Note(duration: duration, pitch: pitch, tie: .regular)

        #expect(note1 == note2)
    }

    @Test
    func inequality() throws {
        let octave = try #require(ABCPitch.Octave(uintValue: 4))
        let pitch = ABCPitch(letter: .c, accidental: .natural, octave: octave)
        let duration = ABC.Duration(numberValue: Number(numerator: 1, denominator: 4))

        #expect(ABC.Note(duration: duration, pitch: pitch, tie: .regular) !=
                ABC.Note(duration: duration, pitch: pitch, tie: nil))
    }

    @Test
    func init_storesProperties() throws {
        let octave = try #require(ABCPitch.Octave(uintValue: 4))
        let pitch = ABCPitch(letter: .g, accidental: .sharp, octave: octave)
        let duration = ABC.Duration(numberValue: Number(numerator: 3, denominator: 8))

        let note = ABC.Note(duration: duration, pitch: pitch, tie: .dotted)

        #expect(note.duration == duration)
        #expect(note.pitch == pitch)
        #expect(note.tie == .dotted)
    }
}
