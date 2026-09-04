// © 2025–2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import IvorGuido
import IvorModel
import IvorTiming
import IvorTuning
import Testing
import XestiNumbers
import XestiTools

struct GuidoFunctionsTests {
}

// MARK: -

extension GuidoFunctionsTests {
    @Test
    func convertToBeatDuration_fractionOfWholeNote_convertsToBeats() {
        let duration = Guido.Duration(numberValue: Number(numerator: 1, denominator: 2))

        #expect(IvorExtern.convertToBeatDuration(duration) == BeatDuration(2))
    }

    @Test
    func convertToInstrument_midiOnly_looksUpGeneralMIDIName() {
        let instrument = GMNInstrument(name: "", midi: 71)

        #expect(convertToInstrument(instrument) == Instrument("Clarinet"))
    }

    @Test
    func convertToInstrument_nameWins_returnsInstrumentName() {
        let instrument = GMNInstrument(name: "Clarinet", midi: 71)

        #expect(convertToInstrument(instrument) == Instrument("Clarinet"))
    }

    @Test
    func convertToInstrument_neitherNameNorMIDI_returnsVanilla() {
        let instrument = GMNInstrument(name: "")

        #expect(convertToInstrument(instrument) == .vanilla)
    }

    @Test
    func convertToStandardPitch_emptyName_throws() throws {
        let octave = try #require(GMNPitch.Octave(intValue: 1))
        let pitch = Guido.Pitch(accidental: .natural,
                                name: .empty,
                                octave: octave)

        #expect(throws: (any Error).self) {
            try convertToStandardPitch(pitch)
        }
    }

    @Test
    func convertToStandardPitch_explicitOctave_resolvesToIvorOctave() throws {
        let octave = try #require(GMNPitch.Octave(intValue: 2))
        let pitch = Guido.Pitch(accidental: .natural,
                                name: .c,
                                octave: octave)

        let result = try convertToStandardPitch(pitch)

        #expect(result.octave == Pitch.Octave(intValue: 5))
    }

    @Test
    func convertToStandardPitch_mapsAccidentals() throws {
        let octave = try #require(GMNPitch.Octave(intValue: 1))
        let accidentals: [Guido.Pitch.Accidental] = [.natural, .flat, .doubleFlat, .sharp, .doubleSharp]
        let expected: [Pitch.Accidental] = [.natural, .flat, .doubleFlat, .sharp, .doubleSharp]

        #expect(accidentals.count == expected.count)

        for (accidental, exp) in zip(accidentals, expected) {
            let pitch = Guido.Pitch(accidental: accidental, name: .c, octave: octave)
            let result = try convertToStandardPitch(pitch)

            #expect(result.pitchClass.accidental == exp)
        }
    }

    @Test
    func convertToStandardPitch_mapsLetterNames() throws {
        let octave = try #require(GMNPitch.Octave(intValue: 1))
        let names: [Guido.Pitch.Name] = [.a, .b, .c, .d, .e, .f, .g]
        let expected: [Pitch.Letter] = [.a, .b, .c, .d, .e, .f, .g]

        #expect(names.count == expected.count)

        for (name, exp) in zip(names, expected) {
            let pitch = Guido.Pitch(accidental: .natural, name: name, octave: octave)
            let result = try convertToStandardPitch(pitch)

            #expect(result.pitchClass.letter == exp)
        }
    }

    @Test
    func convertToTempo_equivalenceForm_returnsNil() throws {
        let unit = try #require(GMNTempo.Metronome.BeatUnit(1, 4))
        let equivalent = try #require(GMNTempo.Metronome.BeatUnit(1, 8))
        let metronome = GMNTempo.Metronome.equivalence(unit: unit, equivalent: equivalent)

        #expect(convertToTempo(metronome) == nil)
    }

    @Test
    func convertToTempo_rateForm_convertsToQuarterNoteBPM() throws {
        let unit = try #require(GMNTempo.Metronome.BeatUnit(1, 4))
        let metronome = GMNTempo.Metronome.rate(unit: unit, beats: 120)

        #expect(convertToTempo(metronome) == Tempo(uintValue: 120))
    }

    @Test
    func convertToTempo_rateFormWithEighthNoteUnit_scalesToQuarterNoteBPM() throws {
        let unit = try #require(GMNTempo.Metronome.BeatUnit(1, 8))
        let metronome = GMNTempo.Metronome.rate(unit: unit, beats: 120)

        #expect(convertToTempo(metronome) == Tempo(uintValue: 60))
    }

    @Test
    func determinePartName_noInstrumentTag_returnsEmptyString() {
        let voice = Guido.Voice(symbols: [])

        #expect(determinePartName(voice).isEmpty)
    }

    @Test
    func determinePartName_returnsInstrumentTagName() {
        let voice = Guido.Voice(symbols: [.tag(.instrument(GMNInstrument(name: "Piano")))])

        #expect(determinePartName(voice) == "Piano")
    }

    @Test
    func determineWorkName_multipleTitleBlocks_joinsWithColon() {
        let score = Guido.Score(variables: [],
                                voices: [Guido.Voice(symbols: [.tag(.titleBlock(GMNTitleBlock(kind: .title,
                                                                                              text: "Sonata"))),
                                                               .tag(.titleBlock(GMNTitleBlock(kind: .title,
                                                                                              text: "No. 1")))])])

        #expect(IvorExtern.determineWorkName(score) == "Sonata: No. 1")
    }

    @Test
    func determineWorkName_noVoices_returnsEmptyString() {
        let score = Guido.Score(variables: [], voices: [])

        #expect(IvorExtern.determineWorkName(score).isEmpty)
    }

    @Test
    func determineWorkName_returnsTitleBlockText() {
        let score = Guido.Score(variables: [],
                                voices: [Guido.Voice(symbols: [.tag(.titleBlock(GMNTitleBlock(kind: .title,
                                                                                              text: "My Score")))])])

        #expect(IvorExtern.determineWorkName(score) == "My Score")
    }
}
