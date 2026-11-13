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
    func convertToABCDecorationName_dynamic_namedLevels_roundTrip() throws {
        let dynamics: [Dynamic] = [.pppp, .ppp, .pp, .p, .mp, .mf, .f, .ff, .fff, .ffff]

        for dynamic in dynamics {
            let name = try #require(convertToABCDecorationName(dynamic))

            #expect(convertToDynamic(name) == dynamic)
        }
    }

    @Test
    func convertToABCDecorationName_dynamic_unnamedLevel_returnsNil() throws {
        let dynamic = try #require(Dynamic(numberValue: Number(0.55)))

        #expect(convertToABCDecorationName(dynamic) == nil)
    }

    @Test
    func convertToABCDecorationName_extra_pizzicato_writesSnap() {
        #expect(convertToABCDecorationName(Extra.pizzicato)?.stringValue == "snap")
    }

    @Test(arguments: [Extra.accent,
                      .breathMark,
                      .downBow,
                      .fermata,
                      .harmonic,
                      .marcato,
                      .mordent,
                      .pizzicato,
                      .staccato,
                      .tenuto,
                      .trill,
                      .turn,
                      .upBow])
    func convertToABCDecorationName_extra_tier1Flag_roundTrips(extra: Extra) throws {
        let name = try #require(convertToABCDecorationName(extra))

        #expect(convertToArticulationExtra(name)?.name == extra.name)
    }

    @Test
    func convertToABCDecorationName_extra_unlisted_returnsNil() {
        #expect(convertToABCDecorationName(Extra.slurStart) == nil)
    }

    @Test
    func convertToABCPitch_lowestOctave_throws() throws {
        let octave = try #require(Pitch.Octave(intValue: -1))
        let pitch = Pitch(pitchClass: PitchClass(letter: .c, accidental: .natural),
                          octave: octave)

        #expect(throws: ABC.Error.self) {
            _ = try convertToABCPitch(pitch)
        }
    }

    @Test
    func convertToABCPitch_mapsAccidentals() throws {
        let octave = try #require(Pitch.Octave(intValue: 4))
        let accidentals: [(Pitch.Accidental, ABCPitch.Accidental)] = [(.doubleFlat, .doubleFlat),
                                                                      (.doubleSharp, .doubleSharp),
                                                                      (.flat, .flat),
                                                                      (.natural, .natural),
                                                                      (.sharp, .sharp)]

        for (accidental, expected) in accidentals {
            let pitch = Pitch(pitchClass: PitchClass(letter: .c, accidental: accidental),
                              octave: octave)

            #expect(try convertToABCPitch(pitch).accidental == expected)
        }
    }

    @Test
    func convertToABCPitch_mapsLetters() throws {
        let octave = try #require(Pitch.Octave(intValue: 4))
        let letters: [(Pitch.Letter, ABCPitch.Letter)] = [(.a, .a),
                                                          (.b, .b),
                                                          (.c, .c),
                                                          (.d, .d),
                                                          (.e, .e),
                                                          (.f, .f),
                                                          (.g, .g)]

        for (letter, expected) in letters {
            let pitch = Pitch(pitchClass: PitchClass(letter: letter, accidental: .natural),
                              octave: octave)

            #expect(try convertToABCPitch(pitch).letter == expected)
        }
    }

    @Test
    func convertToArticulationExtra_aliases_readAsTheirFlag() throws {
        let aliases: [(String, Extra)] = [("emphasis", .accent),
                                          ("invertedfermata", .fermata),
                                          ("lowermordent", .mordent),
                                          ("open", .harmonic),
                                          ("plus", .pizzicato),
                                          ("uppermordent", .mordent)]

        for (text, extra) in aliases {
            let name = try #require(ABCDecoration.Name(stringValue: text))

            #expect(convertToArticulationExtra(name)?.name == extra.name)
        }
    }

    @Test
    func convertToArticulationExtra_ignoresCase() throws {
        let name = try #require(ABCDecoration.Name(stringValue: "TRILL"))

        #expect(convertToArticulationExtra(name)?.name == Extra.trill.name)
    }

    @Test
    func convertToArticulationExtra_unrecognized_returnsNil() throws {
        let name = try #require(ABCDecoration.Name(stringValue: "sfz"))

        #expect(convertToArticulationExtra(name) == nil)
    }

    @Test
    func convertToBeatDuration() throws {
        let duration = ABC.Duration(numberValue: Number(numerator: 1, denominator: 4))

        #expect(try IvorExtern.convertToBeatDuration(duration) == dur(1, 4))
    }

    @Test
    func convertToChannel_bareChannelDirective_returnsChannel() throws {
        let name = try #require(ABCDirective.Name(stringValue: "MIDI"))
        let directive = ABCDirective(name: name, value: "channel 5")

        #expect(convertToChannel(directive) == 5)
    }

    @Test
    func convertToChannel_nonMIDIDirective_returnsNil() {
        let directive = ABCDirective(name: .linebreak, value: "channel 5")

        #expect(convertToChannel(directive) == nil)
    }

    @Test
    func convertToChannel_outOfRange_returnsNil() throws {
        let name = try #require(ABCDirective.Name(stringValue: "MIDI"))
        let directive = ABCDirective(name: name, value: "channel 17")

        #expect(convertToChannel(directive) == nil)
    }

    @Test
    func convertToChannel_programDirective_returnsNil() throws {
        let name = try #require(ABCDirective.Name(stringValue: "MIDI"))
        let directive = ABCDirective(name: name, value: "program 1 40")

        #expect(convertToChannel(directive) == nil)
    }

    @Test
    func convertToDynamic_ignoresCase() throws {
        let name = try #require(ABCDecoration.Name(stringValue: "FF"))

        #expect(convertToDynamic(name) == .ff)
    }

    @Test
    func convertToDynamic_unrecognized_returnsNil() throws {
        let name = try #require(ABCDecoration.Name(stringValue: "sfz"))

        #expect(convertToDynamic(name) == nil)
    }

    @Test
    func convertToInstrument_missingProgramKeyword_returnsNil() throws {
        let name = try #require(ABCDirective.Name(stringValue: "MIDI"))
        let directive = ABCDirective(name: name, value: "channel 1")

        #expect(convertToInstrument(directive, programBase: 0) == nil)
    }

    @Test
    func convertToInstrument_nonMIDIDirective_returnsNil() {
        let directive = ABCDirective(name: .linebreak, value: "program 40")

        #expect(convertToInstrument(directive, programBase: 0) == nil)
    }

    @Test(arguments: [(0, "program 128"), (0, "program -1"), (1, "program 129"), (1, "program 0")])
    func convertToInstrument_programOutOfRange_returnsNil(_ programBase: Int,
                                                          _ value: String) throws {
        let name = try #require(ABCDirective.Name(stringValue: "MIDI"))
        let directive = ABCDirective(name: name, value: value)

        #expect(convertToInstrument(directive, programBase: programBase) == nil)
    }

    @Test
    func convertToInstrument_programWithChannel_usesTrailingProgramNumber() throws {
        let name = try #require(ABCDirective.Name(stringValue: "MIDI"))
        let directive = ABCDirective(name: name, value: "program 1 41")
        let resolved = convertToInstrument(directive, programBase: 1)

        #expect(resolved?.instrument == Instrument("Violin"))
        #expect(resolved?.channel == 1)
        #expect(resolved?.program == 41)
    }

    // abc2midi counts from 0 by default, so `program 40` is the MIDI wire
    // value 40, General MIDI program 41 ("Violin"); counting from 1, as the
    // ABC standard does, it's program 40 ("Synth Bass 2").
    @Test(arguments: [(0, "Violin", 41), (1, "Synth Bass 2", 40)])
    func convertToInstrument_programWithoutChannel_countsFromProgramBase(_ programBase: Int,
                                                                         _ expectedName: String,
                                                                         _ expectedProgram: Int) throws {
        let name = try #require(ABCDirective.Name(stringValue: "MIDI"))
        let directive = ABCDirective(name: name, value: "program 40")
        let resolved = convertToInstrument(directive, programBase: programBase)

        #expect(resolved?.instrument == Instrument(expectedName))
        #expect(resolved?.channel == nil)
        #expect(resolved?.program == expectedProgram)
    }

    @Test(arguments: ["program 40", "programbase", "programbase one"])
    func convertToProgramBase_otherDirective_returnsNil(_ value: String) throws {
        let name = try #require(ABCDirective.Name(stringValue: "MIDI"))

        #expect(convertToProgramBase(ABCDirective(name: name, value: value)) == nil)
    }

    @Test(arguments: [("programbase 0", 0), ("programbase 1", 1), ("programbase 7", 1), ("ProgramBase 0", 0)])
    func convertToProgramBase_programBaseDirective_returnsZeroOrOne(_ value: String,
                                                                    _ expected: Int) throws {
        let name = try #require(ABCDirective.Name(stringValue: "MIDI"))

        #expect(convertToProgramBase(ABCDirective(name: name, value: value)) == expected)
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
    func convertToTempo_compoundBeat_sumsLengthsIntoTheUnit() throws {
        let lengths = try [#require(ABCLength(numerator: 1, denominator: 4)),
                           #require(ABCLength(numerator: 3, denominator: 8))]
        let abcTempo = try #require(ABCTempo(lengths: lengths, rate: 40, text: nil))
        let converted = try #require(convertToTempo(abcTempo))

        // 1/4 + 3/8 = 5/8, at 40 per minute: 25 whole notes per minute.
        #expect(converted == tempo("5/8=40"))
        #expect(converted.numberValue == 25)
    }

    @Test
    func convertToTempo_dottedUnit_keepsTheUnit() throws {
        let lengths = try [#require(ABCLength(numerator: 3, denominator: 8))]
        let abcTempo = try #require(ABCTempo(lengths: lengths, rate: 67, text: nil))

        #expect(convertToTempo(abcTempo) == tempo("3/8=67"))
    }

    @Test
    func convertToTempo_rateForm_keepsAQuarterNoteUnit() throws {
        let lengths = try [#require(ABCLength(numerator: 1, denominator: 4))]
        let abcTempo = try #require(ABCTempo(lengths: lengths, rate: 120, text: nil))

        #expect(convertToTempo(abcTempo) == Tempo(120))
    }

    @Test
    func convertToTempo_textOnly_returnsNil() throws {
        let tempo = try #require(ABCTempo(lengths: [], rate: nil, text: "Allegro"))

        #expect(convertToTempo(tempo) == nil)
    }

    @Test
    func convertToVoiceInstrument_nonMIDIDirective_returnsNil() {
        let directive = ABCDirective(name: .linebreak, value: "voice instrument=59")

        #expect(convertToVoiceInstrument(directive) == nil)
    }

    @Test(arguments: ["program 41", "voice Tb mute", "voice instrument=0", "voice instrument=129", "voice Tb"])
    func convertToVoiceInstrument_noUsableInstrument_returnsNil(_ value: String) throws {
        let name = try #require(ABCDirective.Name(stringValue: "MIDI"))

        #expect(convertToVoiceInstrument(ABCDirective(name: name, value: value)) == nil)
    }

    @Test
    func convertToVoiceInstrument_withIDAndBank_convertsBankToZeroBased() throws {
        let name = try #require(ABCDirective.Name(stringValue: "MIDI"))
        let resolved = convertToVoiceInstrument(ABCDirective(name: name, value: "voice Tb instrument=59 bank=2 mute"))

        #expect(resolved?.voiceID?.stringValue == "Tb")
        #expect(resolved?.instrument == Instrument("Tuba"))
        #expect(resolved?.program == 59)
        #expect(resolved?.bank == 1)
    }

    @Test
    func convertToVoiceInstrument_withoutIDOrBank_leavesBothNil() throws {
        let name = try #require(ABCDirective.Name(stringValue: "MIDI"))
        let resolved = convertToVoiceInstrument(ABCDirective(name: name, value: "voice instrument=41"))

        #expect(resolved != nil)
        #expect(resolved?.voiceID == nil)
        #expect(resolved?.instrument == Instrument("Violin"))
        #expect(resolved?.bank == nil)
    }

    @Test
    func determinePartName_implicitVoice_returnsEmptyString() {
        #expect(determinePartName(nil).isEmpty)
    }

    @Test
    func determinePartName_nameWithExtraWhitespace_collapsesIt() throws {
        let id = try #require(ABCVoice.ID(stringValue: "T1"))
        let voice = try #require(ABCVoice(id: id, properties: ["nm": "  Tenor   Sax "]))

        #expect(determinePartName(voice) == "Tenor Sax")
    }

    @Test
    func determinePartName_nameWithLineBreak_joinsLinesWithSpace() throws {
        let id = try #require(ABCVoice.ID(stringValue: "T1"))
        let voice = try #require(ABCVoice(id: id, properties: ["nm": #"Tenor \nSax"#]))

        #expect(determinePartName(voice) == "Tenor Sax")
    }

    @Test
    func determinePartName_subnameWithLineBreak_joinsLinesWithSpace() throws {
        let id = try #require(ABCVoice.ID(stringValue: "T1"))
        let voice = try #require(ABCVoice(id: id, properties: ["snm": #"T.\nSx."#]))

        #expect(determinePartName(voice) == "T. Sx.")
    }

    @Test(arguments: ["1", "12", "V2", "v3"])
    func determinePartName_voiceNumberIDWithoutName_returnsEmptyString(_ idValue: String) throws {
        let id = try #require(ABCVoice.ID(stringValue: idValue))
        let voice = try #require(ABCVoice(id: id))

        #expect(determinePartName(voice).isEmpty)
    }

    @Test
    func determinePartName_voiceWithoutNameOrSubname_usesVoiceID() throws {
        let id = try #require(ABCVoice.ID(stringValue: "T1"))
        let voice = try #require(ABCVoice(id: id))

        #expect(determinePartName(voice) == "T1")
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
