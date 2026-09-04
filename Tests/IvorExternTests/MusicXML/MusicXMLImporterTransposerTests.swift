// © 2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import IvorMusicXML
import Testing

struct MusicXMLImporterTransposerTests {
}

// MARK: -

extension MusicXMLImporterTransposerTests {
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
