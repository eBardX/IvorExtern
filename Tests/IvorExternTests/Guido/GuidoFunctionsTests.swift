// © 2025–2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import IvorGMN
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

        #expect(IvorExtern.convertToBeatDuration(duration) == dur(1, 2))
    }

    @Test
    func convertToDynamic_ignoresCase() {
        #expect(convertToDynamic("FF") == .ff)
    }

    @Test
    func convertToDynamic_unrecognized_returnsNil() {
        #expect(convertToDynamic("cresc.") == nil)
    }

    @Test
    func convertToGuidoIntensity_namedLevels_roundTrip() throws {
        let dynamics: [Dynamic] = [.pppp, .ppp, .pp, .p, .mp, .mf, .f, .ff, .fff, .ffff]

        for dynamic in dynamics {
            let intensity = try #require(convertToGuidoIntensity(dynamic))

            #expect(convertToDynamic(intensity.type) == dynamic)
        }
    }

    @Test
    func convertToGuidoIntensity_unnamedLevel_returnsNil() throws {
        let dynamic = try #require(Dynamic(numberValue: Number(0.55)))

        #expect(convertToGuidoIntensity(dynamic) == nil)
    }

    @Test(arguments: [("3/4", String?.none, "3/4"),
                      ("2+2+3/8", nil, "2+2+3/8"),
                      ("4/3", nil, "4/3"),
                      ("free", nil, ""),
                      ("4/4", "common", "C"),
                      ("2/2", "cut", "C/"),
                      ("2/2", "common", "2/2")])
    func convertToGuidoMeter_meter(_ plain: String,
                                   _ symbol: String?,
                                   _ expected: String) {
        let extras = symbol.map {
            Extras(elements: [Extra(name: Extra.meterSymbol.name,
                                    values: [.string($0)])])
        }

        #expect(IvorExtern.convertToGuidoMeter(meter(plain), extras).type == expected)
    }

    @Test
    func convertToGuidoPitch_mapsAccidentals() throws {
        let octave = try #require(Pitch.Octave(intValue: 4))
        let accidentals: [(Pitch.Accidental, GMNPitch.Accidental)] = [(.doubleFlat, .doubleFlat),
                                                                      (.doubleSharp, .doubleSharp),
                                                                      (.flat, .flat),
                                                                      (.natural, .omitted),
                                                                      (.sharp, .sharp)]

        for (accidental, expected) in accidentals {
            let pitch = Pitch(pitchClass: PitchClass(letter: .c, accidental: accidental),
                              octave: octave)

            #expect(try convertToGuidoPitch(pitch).accidental == expected)
        }
    }

    @Test
    func convertToGuidoPitch_mapsLetters() throws {
        let octave = try #require(Pitch.Octave(intValue: 4))
        let letters: [(Pitch.Letter, GMNPitch.Name)] = [(.a, .a),
                                                        (.b, .b),
                                                        (.c, .c),
                                                        (.d, .d),
                                                        (.e, .e),
                                                        (.f, .f),
                                                        (.g, .g)]

        for (letter, expected) in letters {
            let pitch = Pitch(pitchClass: PitchClass(letter: letter, accidental: .natural),
                              octave: octave)

            #expect(try convertToGuidoPitch(pitch).name == expected)
        }
    }

    @Test
    func convertToGuidoTag_fingering_roundTripsItsText() throws {
        let extra = Extra(name: Extra.fingering.name, values: [.string("3")])
        let tag = try #require(convertToGuidoTag(extra, body: [.note(makeGMNNote())]))
        let context = try walkGMN([.tag(tag)])

        #expect(stringValue(context.noteTable.map(\.extras).first.flatMap(\.self), .fingering) == "3")
    }

    @Test
    func convertToGuidoTag_fingeringWithoutText_returnsNil() throws {
        let note = try makeGMNNote()

        #expect(convertToGuidoTag(.fingering, body: [.note(note)]) == nil)
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
    func convertToGuidoTag_tier1Flag_roundTripsThroughTheWalker(extra: Extra) throws {
        let tag = try #require(convertToGuidoTag(extra, body: [.note(makeGMNNote())]))
        let context = try walkGMN([.tag(tag)])

        #expect(hasFlag(context.noteTable.map(\.extras).first.flatMap(\.self), extra))
    }

    @Test
    func convertToGuidoTag_unlistedExtra_returnsNil() throws {
        let note = try makeGMNNote()

        #expect(convertToGuidoTag(.slurStart, body: [.note(note)]) == nil)
    }

    @Test
    func convertToGuidoTempo_dottedUnit_writesTheUnitAndRate() throws {
        let gTempo = try #require(convertToGuidoTempo(tempo("3/8=67")))
        let unit = try #require(GMNTempo.Metronome.BeatUnit(3, 8))

        #expect(gTempo.metronome == .rate(unit: unit, beats: 67))
    }

    @Test
    func convertToGuidoTempo_fractionalRate_roundsHalvesUp() throws {
        let gTempo = try #require(convertToGuidoTempo(tempo("3/8=133/2")))
        let unit = try #require(GMNTempo.Metronome.BeatUnit(3, 8))

        #expect(gTempo.metronome == .rate(unit: unit, beats: 67))
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

    @Test(arguments: [("C", "4/4", String?("common")),
                      ("c/", "2/2", "cut"),
                      ("", "free", nil),
                      (" 6/8 ", "6/8", nil),
                      ("2+2+3/8", "2+2+3/8", nil),
                      ("7/12", "7/12", nil)])
    func convertToMeter_type(_ type: String,
                             _ plain: String,
                             _ symbol: String?) {
        let tag = GMNMeter(type: type)

        #expect(IvorExtern.convertToMeter(tag)?.plain == plain)
        #expect(stringValue(IvorExtern.convertToMeterExtras(tag), .meterSymbol) == symbol)
    }

    @Test
    func convertToMeter_unreadableType_isNil() {
        #expect(IvorExtern.convertToMeter(GMNMeter(type: "3/4+3/8")) == nil)
    }

    @Test(arguments: [nil, "lefthand", "LeftHand", "pluck"])
    func convertToPizzicatoExtra_noOrUnknownType_returnsPizzicatoFlag(_ type: String?) {
        #expect(convertToPizzicatoExtra(type) == .pizzicato)
    }

    @Test(arguments: [("bartok", "bartokPizzicato"),
                      ("buzz", "buzzPizzicato"),
                      ("Fingernail", "fingernailPizzicato"),
                      ("snap", "snapPizzicato")])
    func convertToPizzicatoExtra_variantType_returnsArticulationCatchAll(_ type: String,
                                                                         _ expected: String) {
        #expect(convertToPizzicatoExtra(type) == Extra(name: Extra.articulation.name,
                                                       values: [.string(expected)]))
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

        #expect(convertToTempo(metronome) == Tempo(120))
    }

    @Test
    func convertToTempo_rateFormWithDottedUnit_keepsTheUnit() throws {
        let unit = try #require(GMNTempo.Metronome.BeatUnit(3, 8))
        let metronome = GMNTempo.Metronome.rate(unit: unit, beats: 67)

        #expect(convertToTempo(metronome) == tempo("3/8=67"))
    }

    @Test
    func convertToTempo_rateFormWithEighthNoteUnit_keepsTheUnit() throws {
        let unit = try #require(GMNTempo.Metronome.BeatUnit(1, 8))
        let metronome = GMNTempo.Metronome.rate(unit: unit, beats: 120)
        let converted = try #require(convertToTempo(metronome))

        #expect(converted == tempo("1/8=120"))
        #expect(converted.numberValue == Tempo(60).numberValue)
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
