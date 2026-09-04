// © 2025–2026 John Gary Pusey (see LICENSE.md)

import IvorABC
@testable import IvorExtern
import IvorModel
import IvorTiming
import IvorTuning
import Testing
import XestiNumbers
import XestiTools

struct ABCFunctionsTests {
}

// MARK: -

extension ABCFunctionsTests {
    @Test
    func convertToBeatDuration() throws {
        let duration = ABC.Duration(numberValue: Number(numerator: 1, denominator: 4))

        #expect(try IvorExtern.convertToBeatDuration(duration) == BeatDuration(1))
    }

    @Test
    func convertToInstrument_missingProgramKeyword_returnsNil() throws {
        let name = try #require(ABCDirective.Name(stringValue: "MIDI"))
        let directive = ABCDirective(name: name, value: "channel 1")

        #expect(convertToInstrument(directive) == nil)
    }

    @Test
    func convertToInstrument_nonMIDIDirective_returnsNil() {
        let directive = ABCDirective(name: .linebreak, value: "program 40")

        #expect(convertToInstrument(directive) == nil)
    }

    @Test
    func convertToInstrument_programWithChannel_usesTrailingProgramNumber() throws {
        let name = try #require(ABCDirective.Name(stringValue: "MIDI"))
        let directive = ABCDirective(name: name, value: "program 1 40")

        #expect(convertToInstrument(directive) == Instrument("Violin"))
    }

    @Test
    func convertToInstrument_programWithoutChannel_looksUpGeneralMIDIName() throws {
        let name = try #require(ABCDirective.Name(stringValue: "MIDI"))
        let directive = ABCDirective(name: name, value: "program 40")

        #expect(convertToInstrument(directive) == Instrument("Violin"))
    }

    @Test
    func convertToStandardPitch_mapsAccidentals() throws {
        let accidentals: [(ABC.Pitch.Accidental, Pitch.Accidental)] = [(.doubleFlat, .doubleFlat),
                                                                       (.doubleSharp, .doubleSharp),
                                                                       (.flat, .flat),
                                                                       (.natural, .natural),
                                                                       (.sharp, .sharp)]

        for (apAccidental, expected) in accidentals {
            let octave = try #require(ABCPitch.Octave(uintValue: 4))
            let pitch = try convertToStandardPitch(ABCPitch(letter: .c,
                                                            accidental: apAccidental,
                                                            octave: octave))

            #expect(pitch.pitchClass.accidental == expected)
        }
    }

    @Test
    func convertToStandardPitch_mapsLetterAndOctave() throws {
        let letters: [(ABC.Pitch.Letter, Pitch.Letter)] = [(.a, .a),
                                                           (.b, .b),
                                                           (.c, .c),
                                                           (.d, .d),
                                                           (.e, .e),
                                                           (.f, .f),
                                                           (.g, .g)]

        for (apLetter, expected) in letters {
            let octave = try #require(ABCPitch.Octave(uintValue: 5))
            let pitch = try convertToStandardPitch(ABCPitch(letter: apLetter,
                                                            accidental: .natural,
                                                            octave: octave))

            #expect(pitch.pitchClass.letter == expected)
            #expect(pitch.octave == Pitch.Octave(intValue: 5))
        }
    }

    @Test
    func convertToStandardPitch_omittedAccidental_throws() throws {
        let octave = try #require(ABCPitch.Octave(uintValue: 4))

        #expect(throws: (any Error).self) {
            try convertToStandardPitch(ABCPitch(letter: .c,
                                                accidental: .omitted,
                                                octave: octave))
        }
    }

    @Test
    func convertToTempo_compoundBeat_sumsLengthsBeforeScaling() throws {
        let lengths = try [#require(ABCLength(numerator: 1, denominator: 4)),
                           #require(ABCLength(numerator: 3, denominator: 8))]
        let tempo = try #require(ABCTempo(lengths: lengths, rate: 40, text: nil))

        // (1/4 + 3/8) whole notes × 40 × 4 = 100.
        #expect(convertToTempo(tempo) == Tempo(uintValue: 100))
    }

    @Test
    func convertToTempo_rateForm_convertsToQuarterNoteBPM() throws {
        let lengths = try [#require(ABCLength(numerator: 1, denominator: 4))]
        let tempo = try #require(ABCTempo(lengths: lengths, rate: 120, text: nil))

        #expect(convertToTempo(tempo) == Tempo(uintValue: 120))
    }

    @Test
    func convertToTempo_textOnly_returnsNil() throws {
        let tempo = try #require(ABCTempo(lengths: [], rate: nil, text: "Allegro"))

        #expect(convertToTempo(tempo) == nil)
    }

    @Test
    func determinePartName_implicitVoice_returnsEmptyString() {
        #expect(determinePartName(nil).isEmpty)
    }

    @Test
    func determinePartName_voiceWithoutNameOrSubname_usesVoiceID() throws {
        let id = try #require(ABCVoice.ID(stringValue: "1"))
        let voice = try #require(ABCVoice(id: id))

        #expect(determinePartName(voice) == "1")
    }

    @Test
    func determineWorkName() throws {
        let title = try #require(ABCText(stringValue: "My Tune"))
        let header: [ABCHeaderEntry] = try [.field(.referenceNumber(#require(ABCReferenceNumber(uintValue: 1)))),
                                            .field(.tuneTitle(title))]
        let tune = try #require(ABCTune(header: header, body: []))

        #expect(IvorExtern.determineWorkName(tune) == "My Tune")
    }

    @Test
    func determineWorkName_noTitleField_returnsEmptyString() throws {
        let header: [ABCHeaderEntry] = try [.field(.referenceNumber(#require(ABCReferenceNumber(uintValue: 1))))]
        let tune = try #require(ABCTune(header: header, body: []))

        #expect(IvorExtern.determineWorkName(tune).isEmpty)
    }
}
