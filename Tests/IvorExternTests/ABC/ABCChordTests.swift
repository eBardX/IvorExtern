// © 2026 John Gary Pusey (see LICENSE.md)

import IvorABC
@testable import IvorExtern
import Testing
import XestiNumbers

struct ABCChordTests {
}

// MARK: -

extension ABCChordTests {
    @Test
    func equality() throws {
        let octave = try #require(ABCPitch.Octave(uintValue: 4))
        let pitch = ABCPitch(letter: .c, accidental: .natural, octave: octave)
        let duration = ABC.Duration(numberValue: Number(numerator: 1, denominator: 4))
        let note = ABC.Note(duration: duration, pitch: pitch, tie: nil)
        let chord1 = ABC.Chord(notes: [note], tie: .regular)
        let chord2 = ABC.Chord(notes: [note], tie: .regular)

        #expect(chord1 == chord2)
    }

    @Test
    func inequality() throws {
        let octave = try #require(ABCPitch.Octave(uintValue: 4))
        let pitch = ABCPitch(letter: .c, accidental: .natural, octave: octave)
        let duration = ABC.Duration(numberValue: Number(numerator: 1, denominator: 4))
        let note = ABC.Note(duration: duration, pitch: pitch, tie: nil)
        let chord1 = ABC.Chord(notes: [note], tie: .regular)
        let chord2 = ABC.Chord(notes: [note], tie: nil)

        #expect(chord1 != chord2)
    }

    @Test
    func init_storesProperties() throws {
        let octave = try #require(ABCPitch.Octave(uintValue: 4))
        let pitch1 = ABCPitch(letter: .c, accidental: .natural, octave: octave)
        let pitch2 = ABCPitch(letter: .e, accidental: .natural, octave: octave)
        let duration = ABC.Duration(numberValue: Number(numerator: 1, denominator: 4))
        let note1 = ABC.Note(duration: duration, pitch: pitch1, tie: nil)
        let note2 = ABC.Note(duration: duration, pitch: pitch2, tie: .dotted)

        let chord = ABC.Chord(notes: [note1, note2], tie: .regular)

        #expect(chord.notes == [note1, note2])
        #expect(chord.tie == .regular)
    }
}
