// © 2025–2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import IvorGuido
import Testing
import XestiNumbers

struct GuidoNoteTests {
}

// MARK: -

extension GuidoNoteTests {
    @Test
    func equality() throws {
        let octave = try #require(GMNPitch.Octave(intValue: 1))
        let duration = Guido.Duration(numberValue: Number(numerator: 1, denominator: 4))
        let pitch = Guido.Pitch(accidental: .natural, name: .c, octave: octave)

        let note1 = Guido.Note(duration: duration, pitch: pitch)
        let note2 = Guido.Note(duration: duration, pitch: pitch)

        #expect(note1 == note2)
    }

    @Test
    func inequality() throws {
        let octave = try #require(GMNPitch.Octave(intValue: 1))
        let duration = Guido.Duration(numberValue: Number(numerator: 1, denominator: 4))

        let note1 = Guido.Note(duration: duration, pitch: Guido.Pitch(accidental: .natural, name: .c, octave: octave))
        let note2 = Guido.Note(duration: duration, pitch: Guido.Pitch(accidental: .natural, name: .d, octave: octave))

        #expect(note1 != note2)
    }

    @Test
    func init_storesDurationAndPitch() throws {
        let octave = try #require(GMNPitch.Octave(intValue: 2))
        let duration = Guido.Duration(numberValue: Number(numerator: 1, denominator: 8))
        let pitch = Guido.Pitch(accidental: .flat, name: .b, octave: octave)

        let note = Guido.Note(duration: duration, pitch: pitch)

        #expect(note.duration == duration)
        #expect(note.pitch == pitch)
    }
}
