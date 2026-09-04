// © 2025–2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import IvorGuido
import Testing
import XestiNumbers

struct GuidoChordTests {
}

// MARK: -

extension GuidoChordTests {
    @Test
    func equality() throws {
        let octave = try #require(GMNPitch.Octave(intValue: 1))
        let note = Guido.Note(duration: Guido.Duration(numberValue: Number(numerator: 1, denominator: 4)),
                              pitch: Guido.Pitch(accidental: .natural, name: .c, octave: octave))
        let chord1 = Guido.Chord(notes: [note])
        let chord2 = Guido.Chord(notes: [note])

        #expect(chord1 == chord2)
    }

    @Test
    func inequality() throws {
        let octave = try #require(GMNPitch.Octave(intValue: 1))
        let note1 = Guido.Note(duration: Guido.Duration(numberValue: Number(numerator: 1, denominator: 4)),
                               pitch: Guido.Pitch(accidental: .natural, name: .c, octave: octave))
        let note2 = Guido.Note(duration: Guido.Duration(numberValue: Number(numerator: 1, denominator: 4)),
                               pitch: Guido.Pitch(accidental: .natural, name: .d, octave: octave))
        let chord1 = Guido.Chord(notes: [note1])
        let chord2 = Guido.Chord(notes: [note2])

        #expect(chord1 != chord2)
    }

    @Test
    func init_storesNotes() throws {
        let octave = try #require(GMNPitch.Octave(intValue: 1))
        let note1 = Guido.Note(duration: Guido.Duration(numberValue: Number(numerator: 1, denominator: 4)),
                               pitch: Guido.Pitch(accidental: .natural, name: .c, octave: octave))
        let note2 = Guido.Note(duration: Guido.Duration(numberValue: Number(numerator: 1, denominator: 2)),
                               pitch: Guido.Pitch(accidental: .sharp, name: .e, octave: octave))

        let chord = Guido.Chord(notes: [note1, note2])

        #expect(chord.notes == [note1, note2])
    }
}
