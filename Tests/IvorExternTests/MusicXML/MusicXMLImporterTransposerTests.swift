// © 2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import IvorMXL
import Testing

struct MusicXMLImporterTransposerTests {
}

// MARK: -

extension MusicXMLImporterTransposerTests {
    @Test
    func transpose_belowOctaveZero_throws() throws {
        let transposer = MusicXML.Importer.Transposer()
        let octave = try #require(MXLOctave(uintValue: 0))
        let pitch = MXLPitch(step: .c,
                             octave: octave)
        let transpose = MXLTranspose(content: .init(chromatic: -1))

        #expect(throws: MusicXML.Error.self) {
            try transposer.transpose(pitch,
                                     by: transpose,
                                     context: "note")
        }
    }

    @Test
    func transpose_chromaticOnly_choosesCanonicalSharpSpelling() throws {
        let transposer = MusicXML.Importer.Transposer()
        let octave = try #require(MXLOctave(uintValue: 5))
        let pitch = MXLPitch(step: .c,
                             octave: octave)
        let transpose = MXLTranspose(content: .init(chromatic: -2))

        let sounding = try transposer.transpose(pitch,
                                                by: transpose,
                                                context: "note")

        #expect(sounding.step == .a)
        #expect(sounding.octave.uintValue == 4)
        #expect(sounding.alter == 1)
    }

    @Test
    func transpose_chromaticOnly_spellsEveryPitchClassWithSharps() throws {
        let transposer = MusicXML.Importer.Transposer()
        let octave = try #require(MXLOctave(uintValue: 4))
        let pitch = MXLPitch(step: .c,
                             octave: octave)
        let spellings: [(MXLStep, MXLSemitones?)] = [(.c, nil),
                                                     (.c, 1),
                                                     (.d, nil),
                                                     (.d, 1),
                                                     (.e, nil),
                                                     (.f, nil),
                                                     (.f, 1),
                                                     (.g, nil),
                                                     (.g, 1),
                                                     (.a, nil),
                                                     (.a, 1),
                                                     (.b, nil)]

        for (chromatic, spelling) in spellings.enumerated() {
            let transpose = MXLTranspose(content: .init(chromatic: Double(chromatic)))
            let sounding = try transposer.transpose(pitch,
                                                    by: transpose,
                                                    context: "note")

            #expect(sounding.step == spelling.0)
            #expect(sounding.alter == spelling.1)
            #expect(sounding.octave.uintValue == 4)
        }
    }

    @Test
    func transpose_microtonalChromatic_keepsTheRemainderInAlter() throws {
        let transposer = MusicXML.Importer.Transposer()
        let octave = try #require(MXLOctave(uintValue: 4))
        let pitch = MXLPitch(step: .c,
                             octave: octave)
        let transpose = MXLTranspose(content: .init(chromatic: 0.5))

        let sounding = try transposer.transpose(pitch,
                                                by: transpose,
                                                context: "note")

        #expect(sounding.step == .c)
        #expect(sounding.alter == 0.5)
    }

    @Test
    func transpose_nilTranspose_returnsPitchUnchanged() throws {
        let transposer = MusicXML.Importer.Transposer()
        let octave = try #require(MXLOctave(uintValue: 5))
        let pitch = MXLPitch(step: .c,
                             octave: octave)

        let sounding = try transposer.transpose(pitch,
                                                by: nil,
                                                context: "note")

        #expect(sounding == pitch)
    }

    @Test
    func transpose_unrepresentableOctave_throws() throws {
        let transposer = MusicXML.Importer.Transposer()
        let octave = try #require(MXLOctave(uintValue: 5))
        let pitch = MXLPitch(step: .c,
                             octave: octave)
        let octaveChange = try #require(MXLOctaveChange(intValue: 10))
        let transpose = MXLTranspose(content: .init(chromatic: 0,
                                                    octaveChange: octaveChange))

        #expect(throws: (any Error).self) {
            try transposer.transpose(pitch,
                                     by: transpose,
                                     context: "note")
        }
    }

    @Test
    func transpose_withDiatonicShift_belowOctaveZero_throws() throws {
        let transposer = MusicXML.Importer.Transposer()
        let octave = try #require(MXLOctave(uintValue: 0))
        let pitch = MXLPitch(step: .c,
                             octave: octave)
        let diatonic = try #require(MXLDiatonicSteps(intValue: -1))
        let transpose = MXLTranspose(content: .init(diatonic: diatonic,
                                                    chromatic: -1))

        #expect(throws: MusicXML.Error.self) {
            try transposer.transpose(pitch,
                                     by: transpose,
                                     context: "note")
        }
    }

    @Test
    func transpose_withDiatonicShift_fixesLetterSpelling() throws {
        let transposer = MusicXML.Importer.Transposer()
        let octave = try #require(MXLOctave(uintValue: 5))
        let pitch = MXLPitch(step: .c,
                             octave: octave)
        let diatonic = try #require(MXLDiatonicSteps(intValue: -1))
        let transpose = MXLTranspose(content: .init(diatonic: diatonic,
                                                    chromatic: -2))

        let sounding = try transposer.transpose(pitch,
                                                by: transpose,
                                                context: "note")

        #expect(sounding.step == .b)
        #expect(sounding.octave.uintValue == 4)
        #expect(sounding.alter == -1)
    }

    @Test
    func transpose_withDiatonicShift_landsOnEveryLetter() throws {
        let transposer = MusicXML.Importer.Transposer()
        let octave = try #require(MXLOctave(uintValue: 4))
        let pitch = MXLPitch(step: .c,
                             octave: octave)
        let scale: [(MXLStep, Double)] = [(.c, 0),
                                          (.d, 2),
                                          (.e, 4),
                                          (.f, 5),
                                          (.g, 7),
                                          (.a, 9),
                                          (.b, 11)]

        for (shift, degree) in scale.enumerated() {
            let diatonic = try #require(MXLDiatonicSteps(intValue: shift))
            let transpose = MXLTranspose(content: .init(diatonic: diatonic,
                                                        chromatic: degree.1))
            let sounding = try transposer.transpose(pitch,
                                                    by: transpose,
                                                    context: "note")

            #expect(sounding.step == degree.0)
            #expect(sounding.alter == nil)
        }
    }

    @Test
    func transpose_withDiatonicShift_startsFromEveryWrittenLetter() throws {
        let transposer = MusicXML.Importer.Transposer()
        let octave = try #require(MXLOctave(uintValue: 4))
        let diatonic = try #require(MXLDiatonicSteps(intValue: 7))
        let transpose = MXLTranspose(content: .init(diatonic: diatonic,
                                                    chromatic: 12))

        for step: MXLStep in [.a, .b, .c, .d, .e, .f, .g] {
            let sounding = try transposer.transpose(MXLPitch(step: step,
                                                             octave: octave),
                                                    by: transpose,
                                                    context: "note")

            #expect(sounding.step == step)
            #expect(sounding.alter == nil)
            #expect(sounding.octave.uintValue == 5)
        }
    }

    @Test
    func transpose_withDoubleAbove_shiftsUpOneOctave() throws {
        let transposer = MusicXML.Importer.Transposer()
        let octave = try #require(MXLOctave(uintValue: 5))
        let pitch = MXLPitch(step: .c,
                             octave: octave)
        let transpose = MXLTranspose(content: .init(chromatic: 0,
                                                    double: MXLDouble(isAbove: true)))

        let sounding = try transposer.transpose(pitch,
                                                by: transpose,
                                                context: "note")

        #expect(sounding.step == .c)
        #expect(sounding.octave.uintValue == 6)
        #expect(sounding.alter == nil)
    }

    @Test
    func transpose_withDoubleBelow_shiftsDownOneOctave() throws {
        let transposer = MusicXML.Importer.Transposer()
        let octave = try #require(MXLOctave(uintValue: 5))
        let pitch = MXLPitch(step: .c,
                             octave: octave)
        let transpose = MXLTranspose(content: .init(chromatic: 0,
                                                    double: MXLDouble()))

        let sounding = try transposer.transpose(pitch,
                                                by: transpose,
                                                context: "note")

        #expect(sounding.step == .c)
        #expect(sounding.octave.uintValue == 4)
        #expect(sounding.alter == nil)
    }

    @Test
    func transpose_withOctaveChange_shiftsWholeOctaves() throws {
        let transposer = MusicXML.Importer.Transposer()
        let octave = try #require(MXLOctave(uintValue: 5))
        let pitch = MXLPitch(step: .c,
                             octave: octave)
        let octaveChange = try #require(MXLOctaveChange(intValue: -1))
        let transpose = MXLTranspose(content: .init(chromatic: 0,
                                                    octaveChange: octaveChange))

        let sounding = try transposer.transpose(pitch,
                                                by: transpose,
                                                context: "note")

        #expect(sounding.step == .c)
        #expect(sounding.octave.uintValue == 4)
        #expect(sounding.alter == nil)
    }
}
