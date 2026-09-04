// © 2025–2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import IvorGuido
import Testing

struct GuidoPitchTests {
}

// MARK: -

extension GuidoPitchTests {
    @Test
    func equality() throws {
        let octave = try #require(GMNPitch.Octave(intValue: 1))

        let pitch1 = Guido.Pitch(accidental: .natural, name: .c, octave: octave)
        let pitch2 = Guido.Pitch(accidental: .natural, name: .c, octave: octave)

        #expect(pitch1 == pitch2)
    }

    @Test
    func inequality() throws {
        let octave1 = try #require(GMNPitch.Octave(intValue: 1))
        let octave2 = try #require(GMNPitch.Octave(intValue: 2))

        let pitch1 = Guido.Pitch(accidental: .natural, name: .c, octave: octave1)
        let pitch2 = Guido.Pitch(accidental: .natural, name: .c, octave: octave2)

        #expect(pitch1 != pitch2)
    }

    @Test
    func init_storesAccidentalNameAndOctave() throws {
        let octave = try #require(GMNPitch.Octave(intValue: 3))

        let pitch = Guido.Pitch(accidental: .sharp, name: .f, octave: octave)

        #expect(pitch.accidental == .sharp)
        #expect(pitch.name == .f)
        #expect(pitch.octave == octave)
    }
}
