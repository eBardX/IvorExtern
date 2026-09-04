// © 2026 John Gary Pusey (see LICENSE.md)

import IvorABC
@testable import IvorExtern
import Testing
import XestiNumbers

struct ABCImporterRhythmTests {
    private let rhythm = ABC.Importer.Rhythm()
}

// MARK: -

extension ABCImporterRhythmTests {
    @Test
    func advanceDuration_chord_returnsFirstNoteDuration() throws {
        let pitch = try ABCPitch(letter: .c, accidental: .natural, octave: #require(ABCPitch.Octave(uintValue: 4)))
        let duration1 = ABC.Duration(numberValue: Number(numerator: 1, denominator: 4))
        let duration2 = ABC.Duration(numberValue: Number(numerator: 1, denominator: 8))
        let note1 = ABC.Note(duration: duration1, pitch: pitch, tie: nil)
        let note2 = ABC.Note(duration: duration2, pitch: pitch, tie: nil)
        let chord = ABC.Chord(notes: [note1, note2], tie: nil)

        let result = rhythm.advanceDuration(.chord(chord))

        #expect(result == duration1)
    }

    @Test
    func advanceDuration_note_returnsNoteDuration() throws {
        let duration = ABC.Duration(numberValue: Number(numerator: 1, denominator: 4))
        let pitch = try ABCPitch(letter: .c, accidental: .natural, octave: #require(ABCPitch.Octave(uintValue: 4)))
        let note = ABC.Note(duration: duration, pitch: pitch, tie: nil)

        let result = rhythm.advanceDuration(.note(note))

        #expect(result == duration)
    }

    @Test
    func advanceDuration_rest_returnsRestDuration() {
        let duration = ABC.Duration(numberValue: Number(numerator: 1, denominator: 2))
        let rest = ABC.Rest(duration: duration)

        let result = rhythm.advanceDuration(.rest(rest))

        #expect(result == duration)
    }

    @Test
    func brokenRhythmFactor_dotted_isLeft_returnsLongFactor() {
        let result = rhythm.brokenRhythmFactor(.dotted, isLeft: true)

        #expect(result.numerator == 3)
        #expect(result.denominator == 2)
    }

    @Test
    func brokenRhythmFactor_dotted_isRight_returnsShortFactor() {
        let result = rhythm.brokenRhythmFactor(.dotted, isLeft: false)

        #expect(result.numerator == 1)
        #expect(result.denominator == 2)
    }

    @Test
    func brokenRhythmFactor_doubleDotted_returnsFactorForTwoCharacters() {
        let result = rhythm.brokenRhythmFactor(.doubleDotted, isLeft: true)

        #expect(result.numerator == 7)
        #expect(result.denominator == 4)
    }

    @Test
    func brokenRhythmFactor_reverseDotted_isLeft_returnsShortFactor() {
        let result = rhythm.brokenRhythmFactor(.reverseDotted, isLeft: true)

        #expect(result.numerator == 1)
        #expect(result.denominator == 2)
    }

    @Test
    func consumedScale_combinesTupletAndBrokenRhythm() {
        var context = ABC.Importer.Context()
        context.pendingTuplet = (beatCount: 2, noteCount: 3, remainingCount: 1)
        context.pendingBrokenRhythmRight = (numerator: 3, denominator: 2)

        let scale = rhythm.consumedScale(&context)

        #expect(scale.numerator == 6)
        #expect(scale.denominator == 6)
    }

    @Test
    func consumedScale_noPendingState_returnsUnity() {
        var context = ABC.Importer.Context()

        let scale = rhythm.consumedScale(&context)

        #expect(scale.numerator == 1)
        #expect(scale.denominator == 1)
    }

    @Test
    func consumedScale_pendingBrokenRhythmRight_appliesFactorAndClearsIt() {
        var context = ABC.Importer.Context()
        context.pendingBrokenRhythmRight = (numerator: 3, denominator: 2)

        let scale = rhythm.consumedScale(&context)

        #expect(scale.numerator == 3)
        #expect(scale.denominator == 2)
        #expect(context.pendingBrokenRhythmRight == nil)
    }

    @Test
    func consumedScale_pendingTuplet_appliesRatioAndDecrementsRemaining() {
        var context = ABC.Importer.Context()
        context.pendingTuplet = (beatCount: 2, noteCount: 3, remainingCount: 2)

        let scale = rhythm.consumedScale(&context)

        #expect(scale.numerator == 2)
        #expect(scale.denominator == 3)
        #expect(context.pendingTuplet?.remainingCount == 1)
    }

    @Test
    func consumedScale_pendingTupletExhausted_clearsPendingTuplet() {
        var context = ABC.Importer.Context()
        context.pendingTuplet = (beatCount: 2, noteCount: 3, remainingCount: 1)

        _ = rhythm.consumedScale(&context)

        #expect(context.pendingTuplet == nil)
    }

    @Test
    func defaultUnitNoteLength_nilMeter_returnsEighth() {
        let result = rhythm.defaultUnitNoteLength(nil)

        #expect(result.numerator == 1)
        #expect(result.denominator == 8)
    }

    @Test
    func defaultUnitNoteLength_ratioAtOrAboveThreeQuarters_returnsEighth() {
        let result = rhythm.defaultUnitNoteLength(.common)

        #expect(result.numerator == 1)
        #expect(result.denominator == 8)
    }

    @Test
    func defaultUnitNoteLength_ratioBelowThreeQuarters_returnsSixteenth() throws {
        let meter = try ABCTimeSignature.standard(#require(ABCTimeSignature.StandardMeter(numerator: 3, denominator: 8)))

        let result = rhythm.defaultUnitNoteLength(meter)

        #expect(result.numerator == 1)
        #expect(result.denominator == 16)
    }

    @Test
    func measureDuration_complex_sumsNumerators() throws {
        let additive = try #require(ABCTimeSignature.AdditiveMeter(numerators: [2, 3, 2], denominator: 8))

        let duration = rhythm.measureDuration(.complex(additive))

        #expect(duration == ABC.Duration(numberValue: Number(numerator: 7, denominator: 8)))
    }

    @Test
    func measureDuration_cut_returnsTwoTwo() {
        let duration = rhythm.measureDuration(.cut)

        #expect(duration == ABC.Duration(numberValue: Number(numerator: 2, denominator: 2)))
    }

    @Test
    func measureDuration_nilMeter_returnsFourFour() {
        let duration = rhythm.measureDuration(nil)

        #expect(duration == ABC.Duration(numberValue: Number(numerator: 4, denominator: 4)))
    }

    @Test
    func measureDuration_standard_usesNumeratorAndDenominator() throws {
        let standardMeter = try #require(ABCTimeSignature.StandardMeter(numerator: 3, denominator: 4))

        let duration = rhythm.measureDuration(.standard(standardMeter))

        #expect(duration == ABC.Duration(numberValue: Number(numerator: 3, denominator: 4)))
    }

    @Test
    func merged_chords_differentNoteCount_returnsNil() throws {
        let pitch = try ABCPitch(letter: .c, accidental: .natural, octave: #require(ABCPitch.Octave(uintValue: 4)))
        let duration = ABC.Duration(numberValue: Number(numerator: 1, denominator: 4))
        let note = ABC.Note(duration: duration, pitch: pitch, tie: nil)
        let chord1 = ABC.Chord(notes: [note, note], tie: .regular)
        let chord2 = ABC.Chord(notes: [note], tie: nil)

        let result = rhythm.merged(.chord(chord1), .chord(chord2))

        #expect(result == nil)
    }

    @Test
    func merged_chords_sameNotesWithTie_returnsCombinedChord() throws {
        let pitch = try ABCPitch(letter: .c, accidental: .natural, octave: #require(ABCPitch.Octave(uintValue: 4)))
        let duration1 = ABC.Duration(numberValue: Number(numerator: 1, denominator: 4))
        let duration2 = ABC.Duration(numberValue: Number(numerator: 1, denominator: 8))
        let note1 = ABC.Note(duration: duration1, pitch: pitch, tie: nil)
        let note2 = ABC.Note(duration: duration2, pitch: pitch, tie: nil)
        let chord1 = ABC.Chord(notes: [note1], tie: .regular)
        let chord2 = ABC.Chord(notes: [note2], tie: nil)

        let result = rhythm.merged(.chord(chord1), .chord(chord2))

        let expectedNote = ABC.Note(duration: duration1 + duration2, pitch: pitch, tie: nil)

        #expect(result == .chord(ABC.Chord(notes: [expectedNote], tie: nil)))
    }

    @Test
    func merged_notes_differentPitch_returnsNil() throws {
        let octave = try #require(ABCPitch.Octave(uintValue: 4))
        let pitch1 = ABCPitch(letter: .c, accidental: .natural, octave: octave)
        let pitch2 = ABCPitch(letter: .d, accidental: .natural, octave: octave)
        let duration = ABC.Duration(numberValue: Number(numerator: 1, denominator: 4))
        let note1 = ABC.Note(duration: duration, pitch: pitch1, tie: .regular)
        let note2 = ABC.Note(duration: duration, pitch: pitch2, tie: nil)

        let result = rhythm.merged(.note(note1), .note(note2))

        #expect(result == nil)
    }

    @Test
    func merged_notes_noTie_returnsNil() throws {
        let pitch = try ABCPitch(letter: .c, accidental: .natural, octave: #require(ABCPitch.Octave(uintValue: 4)))
        let duration = ABC.Duration(numberValue: Number(numerator: 1, denominator: 4))
        let note1 = ABC.Note(duration: duration, pitch: pitch, tie: nil)
        let note2 = ABC.Note(duration: duration, pitch: pitch, tie: nil)

        let result = rhythm.merged(.note(note1), .note(note2))

        #expect(result == nil)
    }

    @Test
    func merged_notes_samePitchWithTie_returnsCombinedNote() throws {
        let pitch = try ABCPitch(letter: .c, accidental: .natural, octave: #require(ABCPitch.Octave(uintValue: 4)))
        let duration1 = ABC.Duration(numberValue: Number(numerator: 1, denominator: 4))
        let duration2 = ABC.Duration(numberValue: Number(numerator: 1, denominator: 4))
        let note1 = ABC.Note(duration: duration1, pitch: pitch, tie: .regular)
        let note2 = ABC.Note(duration: duration2, pitch: pitch, tie: nil)

        let result = rhythm.merged(.note(note1), .note(note2))

        #expect(result == .note(ABC.Note(duration: duration1 + duration2, pitch: pitch, tie: nil)))
    }

    @Test
    func merged_restAndNote_returnsNil() throws {
        let duration = ABC.Duration(numberValue: Number(numerator: 1, denominator: 4))
        let rest = ABC.Rest(duration: duration)
        let pitch = try ABCPitch(letter: .c, accidental: .natural, octave: #require(ABCPitch.Octave(uintValue: 4)))
        let note = ABC.Note(duration: duration, pitch: pitch, tie: nil)

        let result = rhythm.merged(.rest(rest), .note(note))

        #expect(result == nil)
    }

    @Test
    func multiplied_combinesFractions() {
        let result = rhythm.multiplied((numerator: 2, denominator: 3),
                                       (numerator: 4, denominator: 5))

        #expect(result.numerator == 8)
        #expect(result.denominator == 15)
    }

    @Test
    func rescaled_chord_scalesEachNotesDuration() throws {
        let pitch = try ABCPitch(letter: .c, accidental: .natural, octave: #require(ABCPitch.Octave(uintValue: 4)))
        let duration1 = ABC.Duration(numberValue: Number(numerator: 1, denominator: 4))
        let duration2 = ABC.Duration(numberValue: Number(numerator: 1, denominator: 8))
        let note1 = ABC.Note(duration: duration1, pitch: pitch, tie: nil)
        let note2 = ABC.Note(duration: duration2, pitch: pitch, tie: .regular)
        let chord = ABC.Chord(notes: [note1, note2], tie: .regular)

        let rescaled = rhythm.rescaled(.chord(chord), by: (numerator: 3, denominator: 2))

        let expected = ABC.Chord(notes: [ABC.Note(duration: duration1 * (numerator: 3, denominator: 2), pitch: pitch, tie: nil),
                                         ABC.Note(duration: duration2 * (numerator: 3, denominator: 2), pitch: pitch, tie: .regular)],
                                 tie: .regular)

        #expect(rescaled == .chord(expected))
    }

    @Test
    func rescaled_note_scalesDuration() throws {
        let pitch = try ABCPitch(letter: .c, accidental: .natural, octave: #require(ABCPitch.Octave(uintValue: 4)))
        let note = ABC.Note(duration: ABC.Duration(numberValue: Number(numerator: 1, denominator: 4)), pitch: pitch, tie: .regular)

        let rescaled = rhythm.rescaled(.note(note), by: (numerator: 3, denominator: 2))

        #expect(rescaled == .note(ABC.Note(duration: ABC.Duration(numberValue: Number(numerator: 3, denominator: 8)), pitch: pitch, tie: .regular)))
    }

    @Test
    func rescaled_rest_scalesDuration() {
        let rest = ABC.Rest(duration: ABC.Duration(numberValue: Number(numerator: 1, denominator: 4)))

        let rescaled = rhythm.rescaled(.rest(rest), by: (numerator: 3, denominator: 2))

        #expect(rescaled == .rest(ABC.Rest(duration: ABC.Duration(numberValue: Number(numerator: 3, denominator: 8)))))
    }

    @Test
    func resolvedTuplet_defaultBeatCount_forDuple_ignoresCompoundMeter() throws {
        let tuplet = try #require(ABCTuplet(noteCount: 2))

        let resolved = rhythm.resolvedTuplet(tuplet, meter: nil)

        #expect(resolved.beatCount == 3)
        #expect(resolved.noteCount == 2)
        #expect(resolved.affectedCount == 2)
    }

    @Test
    func resolvedTuplet_defaultBeatCount_forOtherNoteCount_dependsOnCompoundMeter() throws {
        let compoundMeter = try ABCTimeSignature.standard(#require(ABCTimeSignature.StandardMeter(numerator: 6, denominator: 8)))
        let tuplet = try #require(ABCTuplet(noteCount: 5))

        let resolved = rhythm.resolvedTuplet(tuplet, meter: compoundMeter)

        #expect(resolved.beatCount == 3)
    }

    @Test
    func resolvedTuplet_defaultBeatCount_forTriple() throws {
        let tuplet = try #require(ABCTuplet(noteCount: 3))

        let resolved = rhythm.resolvedTuplet(tuplet, meter: nil)

        #expect(resolved.beatCount == 2)
    }

    @Test
    func resolvedTuplet_explicitValues_usesGivenValues() throws {
        let tuplet = try #require(ABCTuplet(noteCount: 5, beatCount: 4, affectedCount: 5))

        let resolved = rhythm.resolvedTuplet(tuplet, meter: nil)

        #expect(resolved.beatCount == 4)
        #expect(resolved.noteCount == 5)
        #expect(resolved.affectedCount == 5)
    }
}
