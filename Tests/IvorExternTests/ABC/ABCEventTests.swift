// © 2026 John Gary Pusey (see LICENSE.md)

import IvorABC
@testable import IvorExtern
import Testing
import XestiNumbers

struct ABCEventTests {
}

// MARK: -

extension ABCEventTests {
    @Test
    func equality() {
        let duration = ABC.Duration(numberValue: Number(numerator: 1, denominator: 4))
        let rest1 = ABC.Rest(duration: duration)
        let rest2 = ABC.Rest(duration: duration)

        #expect(ABC.Event.rest(rest1) == ABC.Event.rest(rest2))
    }

    @Test
    func inequality() {
        let rest1 = ABC.Rest(duration: ABC.Duration(numberValue: Number(numerator: 1, denominator: 4)))
        let rest2 = ABC.Rest(duration: ABC.Duration(numberValue: Number(numerator: 1, denominator: 2)))

        #expect(ABC.Event.rest(rest1) != ABC.Event.rest(rest2))
    }

    @Test
    func tie_chord() throws {
        let octave = try #require(ABCPitch.Octave(uintValue: 4))
        let pitch = ABCPitch(letter: .c, accidental: .natural, octave: octave)
        let duration = ABC.Duration(numberValue: Number(numerator: 1, denominator: 4))
        let note = ABC.Note(duration: duration, pitch: pitch, tie: nil)
        let chord = ABC.Chord(notes: [note], tie: .dotted)

        #expect(ABC.Event.chord(chord).tie == .dotted)
    }

    @Test
    func tie_note() throws {
        let octave = try #require(ABCPitch.Octave(uintValue: 4))
        let pitch = ABCPitch(letter: .c, accidental: .natural, octave: octave)
        let duration = ABC.Duration(numberValue: Number(numerator: 1, denominator: 4))
        let note = ABC.Note(duration: duration, pitch: pitch, tie: .regular)

        #expect(ABC.Event.note(note).tie == .regular)
    }

    @Test
    func tie_rest_returnsNil() {
        let rest = ABC.Rest(duration: ABC.Duration(numberValue: Number(numerator: 1, denominator: 4)))

        #expect(ABC.Event.rest(rest).tie == nil)
    }
}
