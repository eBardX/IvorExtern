// © 2026 John Gary Pusey (see LICENSE.md)

import IvorABC
@testable import IvorExtern
import Testing

struct ABCImporterPitchFolderTests {
    private let pitchFolder = ABC.Importer.PitchFolder()
}

// MARK: -

extension ABCImporterPitchFolderTests {
    @Test
    func clef_clefOnly_returnsClef() throws {
        let clef = try #require(ABCClef(name: .treble))

        let result = pitchFolder.clef(from: .clefOnly(clef))

        #expect(result == clef)
    }

    @Test
    func clef_empty_returnsNil() {
        #expect(pitchFolder.clef(from: .empty) == nil)
    }

    @Test
    func clef_highlandPipes_returnsNil() {
        #expect(pitchFolder.clef(from: .highlandPipes) == nil)
    }

    @Test
    func clef_highlandPipesPreset_returnsNil() {
        #expect(pitchFolder.clef(from: .highlandPipesPreset) == nil)
    }

    @Test
    func clef_standard_noClef_returnsNil() throws {
        let standard = try #require(ABCKeySignature.Standard(tonic: .c, mode: .major))

        let result = pitchFolder.clef(from: .standard(standard))

        #expect(result == nil)
    }

    @Test
    func clef_standard_returnsClef() throws {
        let clef = try #require(ABCClef(name: .bass))
        let standard = try #require(ABCKeySignature.Standard(tonic: .c,
                                                             mode: .major,
                                                             clef: clef))

        let result = pitchFolder.clef(from: .standard(standard))

        #expect(result == clef)
    }

    @Test
    func foldedPitch_noClef_appliesNoShift() throws {
        let octave = try #require(ABCPitch.Octave(uintValue: 4))
        let pitch = ABCPitch(letter: .c, accidental: .natural, octave: octave)

        let folded = try pitchFolder.foldedPitch(pitch, nil)

        #expect(folded == pitch)
    }

    @Test
    func foldedPitch_respellsUsingSharpsOnly() throws {
        let octave = try #require(ABCPitch.Octave(uintValue: 4))
        let pitch = ABCPitch(letter: .d, accidental: .flat, octave: octave)

        let folded = try pitchFolder.foldedPitch(pitch, nil)

        #expect(folded.letter == .c)
        #expect(folded.accidental == .sharp)
        #expect(folded.octave.uintValue == 4)
    }

    @Test
    func foldedPitch_throwsWhenOutOfRepresentableRange() throws {
        let clef = try #require(ABCClef(octave: 1))
        let octave = try #require(ABCPitch.Octave(uintValue: 9))
        let pitch = ABCPitch(letter: .c, accidental: .natural, octave: octave)

        #expect(throws: ABC.Error.self) {
            try pitchFolder.foldedPitch(pitch, clef)
        }
    }

    @Test
    func foldedPitch_withTransposeAndOctaveAndOttava_appliesCombinedShift() throws {
        let clef = try #require(ABCClef(ottava: .alta, transpose: 2, octave: 1))
        let octave = try #require(ABCPitch.Octave(uintValue: 4))
        let pitch = ABCPitch(letter: .c, accidental: .natural, octave: octave)

        let folded = try pitchFolder.foldedPitch(pitch, clef)

        #expect(folded.letter == .d)
        #expect(folded.accidental == .natural)
        #expect(folded.octave.uintValue == 6)
    }

    @Test
    func resolvedAccidental_barAccidentalUsedWhenNoneWritten() throws {
        var context = ABC.Importer.Context()
        context.barAccidentals[.c] = .flat

        let octave = try #require(ABCPitch.Octave(uintValue: 4))
        let pitch = ABCPitch(letter: .c, accidental: .omitted, octave: octave)

        let result = pitchFolder.resolvedAccidental(for: pitch, context)

        #expect(result == .flat)
    }

    @Test
    func resolvedAccidental_defaultsToNaturalWhenNoneSet() throws {
        let context = ABC.Importer.Context()
        let octave = try #require(ABCPitch.Octave(uintValue: 4))
        let pitch = ABCPitch(letter: .c, accidental: .omitted, octave: octave)

        let result = pitchFolder.resolvedAccidental(for: pitch, context)

        #expect(result == .natural)
    }

    @Test
    func resolvedAccidental_keyAccidentalUsedWhenNoBarAccidental() throws {
        var context = ABC.Importer.Context()
        context.keyAccidentals[.c] = .sharp

        let octave = try #require(ABCPitch.Octave(uintValue: 4))
        let pitch = ABCPitch(letter: .c, accidental: .omitted, octave: octave)

        let result = pitchFolder.resolvedAccidental(for: pitch, context)

        #expect(result == .sharp)
    }

    @Test
    func resolvedAccidental_writtenAccidentalTakesPrecedence() throws {
        var context = ABC.Importer.Context()
        context.barAccidentals[.c] = .flat
        context.keyAccidentals[.c] = .natural

        let octave = try #require(ABCPitch.Octave(uintValue: 4))
        let pitch = ABCPitch(letter: .c, accidental: .sharp, octave: octave)

        let result = pitchFolder.resolvedAccidental(for: pitch, context)

        #expect(result == .sharp)
    }

    @Test
    func resolvedWrittenPitch_leavesBarAccidentalsUnchangedWhenAccidentalOmitted() throws {
        var context = ABC.Importer.Context()
        context.keyAccidentals[.f] = .sharp

        let octave = try #require(ABCPitch.Octave(uintValue: 4))
        let pitch = ABCPitch(letter: .f, accidental: .omitted, octave: octave)

        let resolved = pitchFolder.resolvedWrittenPitch(pitch, &context)

        #expect(resolved.accidental == .sharp)
        #expect(context.barAccidentals[.f] == nil)
    }

    @Test
    func resolvedWrittenPitch_recordsWrittenAccidentalInBarAccidentals() throws {
        var context = ABC.Importer.Context()

        let octave = try #require(ABCPitch.Octave(uintValue: 4))
        let pitch = ABCPitch(letter: .f, accidental: .sharp, octave: octave)

        let resolved = pitchFolder.resolvedWrittenPitch(pitch, &context)

        #expect(resolved.accidental == .sharp)
        #expect(context.barAccidentals[.f] == .sharp)
    }
}
