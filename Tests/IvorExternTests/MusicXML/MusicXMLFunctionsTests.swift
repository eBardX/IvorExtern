// © 2025–2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import IvorModel
import IvorMXL
import IvorTiming
import IvorTuning
import Testing
import XestiNumbers
import XestiTools

struct MusicXMLFunctionsTests {
}

// MARK: -

extension MusicXMLFunctionsTests {
    @Test
    func convertToDynamic_direction_noDynamicsMark_returnsNil() {
        #expect(convertToDynamic(MXLDirection()) == nil)
    }

    @Test
    func convertToDynamic_direction_readsFirstRecognizedDynamicsMark() {
        let direction = MXLDirection(kind: [MXLDirection.Kind(content: .dynamics([MXLDynamics(items: [.ff])]))])

        #expect(convertToDynamic(direction) == .ff)
    }

    @Test
    func convertToDynamic_item_clampsBeyondNamedLevels() {
        #expect(convertToDynamic(MXLDynamics.Item.ffffff) == .ffff)
        #expect(convertToDynamic(MXLDynamics.Item.pppppp) == .pppp)
    }

    @Test
    func convertToDynamic_item_compoundMark_convertsToSettledLevel() {
        #expect(convertToDynamic(MXLDynamics.Item.fp) == .p)
        #expect(convertToDynamic(MXLDynamics.Item.pf) == .f)
    }

    @Test
    func convertToDynamic_item_momentaryAccent_returnsNil() {
        #expect(convertToDynamic(MXLDynamics.Item.sf) == nil)
        #expect(convertToDynamic(MXLDynamics.Item.sfz) == nil)
    }

    @Test
    func convertToDynamic_item_namedLevels_convertToThemselves() {
        #expect(convertToDynamic(MXLDynamics.Item.fff) == .fff)
        #expect(convertToDynamic(MXLDynamics.Item.mp) == .mp)
        #expect(convertToDynamic(MXLDynamics.Item.ppp) == .ppp)
    }

    @Test
    func convertToDynamic_item_niente_returnsSilence() {
        #expect(convertToDynamic(MXLDynamics.Item.n) == Dynamic(numberValue: 0))
    }

    @Test
    func convertToDynamic_sound_noDynamics_returnsNil() {
        #expect(convertToDynamic(MXLSound()) == nil)
    }

    @Test
    func convertToDynamic_sound_readsDynamicsAttribute() {
        let sound = MXLSound(dynamics: 90)

        #expect(convertToDynamic(sound) == Dynamic(numberValue: Number(numerator: 81, denominator: 127)))
    }

    @Test
    func convertToInstrument_midiProgramFallback_looksUpGeneralMIDIName() throws {
        let program = try #require(MXLMidi128(uintValue: 41))
        let midiInstrument = MXLMidiInstrument(id: "P1-I1", midiProgram: program)
        let scorePart = MXLScorePart(id: "P1",
                                     name: MXLPartName(value: "Strings", text: .init()),
                                     group2: [MXLScorePart.Group2(midiInstrument: midiInstrument)])

        #expect(convertToInstrument(scorePart) == Instrument("Violin"))
    }

    @Test
    func convertToInstrument_midiUnpitchedAndProgramBothPresent_unpitchedTakesPriority() throws {
        let program = try #require(MXLMidi128(uintValue: 1))
        let unpitched = try #require(MXLMidi128(uintValue: 39))
        let midiInstrument = MXLMidiInstrument(id: "P1-I1", midiProgram: program, midiUnpitched: unpitched)
        let scorePart = MXLScorePart(id: "P1",
                                     name: MXLPartName(value: "Drums", text: .init()),
                                     group2: [MXLScorePart.Group2(midiInstrument: midiInstrument)])

        #expect(convertToInstrument(scorePart) == Instrument("Acoustic Snare"))
    }

    @Test
    func convertToInstrument_midiUnpitchedFallback_looksUpGeneralMIDIPercussionName() throws {
        let unpitched = try #require(MXLMidi128(uintValue: 39))
        let midiInstrument = MXLMidiInstrument(id: "P1-I1", midiUnpitched: unpitched)
        let scorePart = MXLScorePart(id: "P1",
                                     name: MXLPartName(value: "Drums", text: .init()),
                                     group2: [MXLScorePart.Group2(midiInstrument: midiInstrument)])

        #expect(convertToInstrument(scorePart) == Instrument("Acoustic Snare"))
    }

    @Test
    func convertToInstrument_neitherNameNorProgram_returnsNil() {
        let scorePart = MXLScorePart(id: "P1", name: MXLPartName(value: "Strings", text: .init()))

        #expect(convertToInstrument(scorePart) == nil)
    }

    @Test
    func convertToInstrument_scoreInstrumentName_returnsInstrument() {
        let scoreInstrument = MXLScoreInstrument(id: "P1-I1", name: "Violin")
        let scorePart = MXLScorePart(id: "P1",
                                     name: MXLPartName(value: "Strings", text: .init()),
                                     instrument: [scoreInstrument])

        #expect(convertToInstrument(scorePart) == Instrument("Violin"))
    }

    @Test
    func convertToMusicXMLDynamics_dynamic_namedLevels_roundTrip() throws {
        let dynamics: [Dynamic] = [.pppp, .ppp, .pp, .p, .mp, .mf, .f, .ff, .fff, .ffff]

        for dynamic in dynamics {
            let item = try #require(convertToMusicXMLDynamics(dynamic))

            #expect(convertToDynamic(item) == dynamic)
        }
    }

    @Test
    func convertToMusicXMLDynamics_dynamic_unnamedLevel_returnsNil() throws {
        let dynamic = try #require(Dynamic(numberValue: Number(0.55)))

        #expect(convertToMusicXMLDynamics(dynamic) == nil)
    }

    @Test
    func convertToMusicXMLDynamics_mark_fixedCases_matchIgnoringCase() {
        let marks: [(String, MXLDynamics.Item)] = [("FZ", .fz),
                                                   ("rf", .rf),
                                                   ("rfz", .rfz),
                                                   ("sf", .sf),
                                                   ("SFZ", .sfz)]

        for (mark, item) in marks {
            #expect(convertToMusicXMLDynamics(mark: mark) == item)
        }
    }

    @Test
    func convertToMusicXMLDynamics_mark_otherText_becomesOtherDynamics() {
        #expect(convertToMusicXMLDynamics(mark: "subito") == .otherDynamics(MXLOtherText(value: "subito")))
    }

    @Test
    func convertToMusicXMLNotationItems_noPayload_dropsPayloadExtras() {
        #expect(convertToMusicXMLNotationItems([.articulation, .fingering]).isEmpty)
    }

    @Test
    func convertToMusicXMLNotationItems_payloadExtras_roundTripThroughImport() throws {
        let extras = Extras(elements: [Extra(name: Extra.articulation.name, values: [.string("flick")]),
                                       Extra(name: Extra.fingering.name, values: [.string("3")])])
        let recovered = try roundTripNoteExtras(extras)

        #expect(stringValue(recovered, .articulation) == "flick")
        #expect(stringValue(recovered, .fingering) == "3")
    }

    @Test
    func convertToMusicXMLNotationItems_pizzicato_writesSnapPizzicato() {
        let snap = MXLTechnical.Item.snapPizzicato(position: MXLPosition(), font: MXLFont(), color: nil, placement: nil)

        #expect(convertToMusicXMLNotationItems([.pizzicato]) == [.technical(MXLTechnical(items: [snap]))])
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
    func convertToMusicXMLNotationItems_tier1Flag_roundTripsThroughImport(extra: Extra) throws {
        #expect(try hasFlag(roundTripNoteExtras(Extras(elements: [extra])), extra))
    }

    @Test
    func convertToMusicXMLNotationItems_unlistedExtra_isDropped() {
        #expect(convertToMusicXMLNotationItems([.slurStart]).isEmpty)
    }

    @Test
    func convertToMusicXMLPitch_lowestOctave_throws() throws {
        let octave = try #require(Pitch.Octave(intValue: -1))
        let pitch = Pitch(pitchClass: PitchClass(letter: .c, accidental: .natural),
                          octave: octave)

        #expect(throws: MusicXML.Error.self) {
            _ = try convertToMusicXMLPitch(pitch)
        }
    }

    @Test
    func convertToMusicXMLPitch_mapsAccidentals() throws {
        let octave = try #require(Pitch.Octave(intValue: 4))
        let accidentals: [(Pitch.Accidental, MusicXML.Semitones?)] = [(.doubleFlat, -2),
                                                                      (.doubleSharp, 2),
                                                                      (.flat, -1),
                                                                      (.natural, nil),
                                                                      (.sharp, 1)]

        for (accidental, alter) in accidentals {
            let pitch = Pitch(pitchClass: PitchClass(letter: .c, accidental: accidental),
                              octave: octave)

            #expect(try convertToMusicXMLPitch(pitch).alter == alter)
        }
    }

    @Test
    func convertToMusicXMLPitch_mapsLetters() throws {
        let octave = try #require(Pitch.Octave(intValue: 4))
        let letters: [(Pitch.Letter, MusicXML.Step)] = [(.a, .a),
                                                        (.b, .b),
                                                        (.c, .c),
                                                        (.d, .d),
                                                        (.e, .e),
                                                        (.f, .f),
                                                        (.g, .g)]

        for (letter, step) in letters {
            let pitch = Pitch(pitchClass: PitchClass(letter: letter, accidental: .natural),
                              octave: octave)

            #expect(try convertToMusicXMLPitch(pitch).step == step)
        }
    }

    @Test
    func convertToPan_midiInstrumentPan_takesPriorityOverDeprecatedSoundPan() {
        let midiInstrument = MXLMidiInstrument(id: "P1-I1",
                                               pan: -90)
        let sound = MXLSound(group: [MXLSound.Group(midiInstrument: midiInstrument)],
                             pan: 90)

        #expect(convertToPan(sound) == .left)
    }

    @Test
    func convertToPan_noPan_returnsNil() {
        #expect(convertToPan(MXLSound()) == nil)
    }

    @Test
    func convertToPan_preservesDegreesBeyondHardSides() {
        let sound = MXLSound(pan: 135)

        #expect(convertToPan(sound) == Pan(horizontal: 135))
    }

    @Test
    func convertToPan_usesDeprecatedSoundPan_whenNoMidiInstrumentPan() {
        let sound = MXLSound(pan: 45)

        #expect(convertToPan(sound) == Pan(horizontal: 45))
    }

    @Test
    func convertToStandardPitch_mapsAlterations() throws {
        let octave = try #require(MXLOctave(uintValue: 4))
        let alterations: [(MXLSemitones?, Pitch.Accidental)] = [(-2, .doubleFlat),
                                                                (-1, .flat),
                                                                (nil, .natural),
                                                                (0, .natural),
                                                                (1, .sharp),
                                                                (2, .doubleSharp)]

        for (alter, expected) in alterations {
            let pitch = try convertToStandardPitch(MXLPitch(step: .c,
                                                            alter: alter,
                                                            octave: octave))

            #expect(pitch.pitchClass.accidental == expected)
        }
    }

    @Test
    func convertToStandardPitch_mapsSteps() throws {
        let octave = try #require(MXLOctave(uintValue: 5))
        let steps: [(MXLStep, Pitch.Letter)] = [(.a, .a),
                                                (.b, .b),
                                                (.c, .c),
                                                (.d, .d),
                                                (.e, .e),
                                                (.f, .f),
                                                (.g, .g)]

        for (step, expected) in steps {
            let pitch = try convertToStandardPitch(MXLPitch(step: step,
                                                            octave: octave))

            #expect(pitch.pitchClass.letter == expected)
            #expect(pitch.octave == Pitch.Octave(intValue: 5))
        }
    }

    @Test
    func convertToStandardPitch_microtonalAlteration_throws() throws {
        let octave = try #require(MXLOctave(uintValue: 4))

        #expect(throws: (any Error).self) {
            try convertToStandardPitch(MXLPitch(step: .c,
                                                alter: 0.5,
                                                octave: octave))
        }
    }

    @Test
    func determinePartName_emptyNameWithInstrument_returnsInstrumentName() {
        let scorePart = MXLScorePart(id: "P1",
                                     name: MXLPartName(value: "",
                                                       text: .init()),
                                     instrument: [MXLScoreInstrument(id: "P1-I1",
                                                                     name: "Koto")])

        #expect(determinePartName(scorePart, groupName: nil) == "Koto")
    }

    @Test
    func determinePartName_emptyNameWithoutInstrument_returnsEmptyString() {
        let scorePart = MXLScorePart(id: "P1",
                                     name: MXLPartName(value: "",
                                                       text: .init()))

        #expect(determinePartName(scorePart, groupName: nil).isEmpty)
    }

    @Test
    func determinePartName_numeralOnlyNameWithGroupName_combinesGroupAndNumerals() {
        let scorePart = MXLScorePart(id: "P8",
                                     name: MXLPartName(value: "1 2",
                                                       text: .init()))

        #expect(determinePartName(scorePart, groupName: "Horns in F") == "Horns in F (1, 2)")
    }

    @Test
    func determinePartName_numeralOnlyNameWithoutGroupName_returnsNameAsIs() {
        let scorePart = MXLScorePart(id: "P8",
                                     name: MXLPartName(value: "1 2",
                                                       text: .init()))

        #expect(determinePartName(scorePart, groupName: nil) == "1 2")
    }

    @Test
    func determinePartName_placeholderNameWithInstrument_returnsInstrumentName() {
        // MuseScore's literal, non-printing default for a part whose name
        // was never set by the user — see `determinePartName`'s own comment.
        let scorePart = MXLScorePart(id: "P1",
                                     name: MXLPartName(value: "MusicXML Part",
                                                       text: .init(printsObject: false)),
                                     instrument: [MXLScoreInstrument(id: "P1-I1",
                                                                     name: "Grand Piano")])

        #expect(determinePartName(scorePart, groupName: nil) == "Grand Piano")
    }

    @Test
    func determinePartName_placeholderNameWithoutInstrument_returnsPlaceholder() {
        let scorePart = MXLScorePart(id: "P1",
                                     name: MXLPartName(value: "MusicXML Part",
                                                       text: .init(printsObject: false)))

        #expect(determinePartName(scorePart, groupName: nil) == "MusicXML Part")
    }

    @Test
    func determinePartName_returnsScorePartNameValue() {
        let scorePart = MXLScorePart(id: "P1",
                                     name: MXLPartName(value: "Violin",
                                                       text: .init()))

        #expect(determinePartName(scorePart, groupName: nil) == "Violin")
    }

    @Test
    func determinePartName_singleNumeralNameWithGroupName_combinesGroupAndNumeral() {
        let scorePart = MXLScorePart(id: "P12",
                                     name: MXLPartName(value: "3",
                                                       text: .init()))

        #expect(determinePartName(scorePart, groupName: "Trombones") == "Trombones (3)")
    }

    @Test
    func determineWorkName_combinesWorkAndMovementTitles() {
        let score = MXLScorePartwise(work: MXLWork(title: "Symphony"),
                                     movementTitle: "Allegro",
                                     partList: MXLPartList())

        #expect(determineWorkName(score) == "Symphony: Allegro")
    }

    @Test
    func determineWorkName_movementNumberOnly_returnsMovementNumber() {
        let score = MXLScorePartwise(movementNumber: "2",
                                     partList: MXLPartList())

        #expect(determineWorkName(score) == "2")
    }

    @Test
    func determineWorkName_noWorkOrMovementInfo_returnsEmptyString() {
        let score = MXLScorePartwise(partList: MXLPartList())

        #expect(determineWorkName(score).isEmpty)
    }

    @Test
    func determineWorkName_workNumberOnly_returnsWorkNumber() {
        let score = MXLScorePartwise(work: MXLWork(number: "Op. 1"),
                                     partList: MXLPartList())

        #expect(determineWorkName(score) == "Op. 1")
    }

    @Test
    func determineWorkName_workTitleOnly_returnsWorkTitle() {
        let score = MXLScorePartwise(work: MXLWork(title: "Symphony"),
                                     partList: MXLPartList())

        #expect(determineWorkName(score) == "Symphony")
    }

    @Test
    func dynamicMarkText_direction_onlyRecognizedMarks_returnsNil() {
        let direction = MXLDirection(kind: [MXLDirection.Kind(content: .dynamics([MXLDynamics(items: [.ff])]))])

        #expect(dynamicMarkText(direction) == nil)
    }

    @Test
    func dynamicMarkText_direction_returnsFirstUnrecognizedMark() {
        let direction = MXLDirection(kind: [MXLDirection.Kind(content: .dynamics([MXLDynamics(items: [.ff, .sfz, .rf])]))])

        #expect(dynamicMarkText(direction) == "sfz")
    }

    @Test
    func dynamicMarkText_item_namesEveryUnrecognizedItem() {
        let items: [(MXLDynamics.Item, String)] = [(.fz, "fz"),
                                                   (.otherDynamics(MXLOtherText(value: "subito")), "subito"),
                                                   (.rf, "rf"),
                                                   (.rfz, "rfz"),
                                                   (.sf, "sf"),
                                                   (.sfz, "sfz")]

        for (item, text) in items {
            #expect(dynamicMarkText(item) == text)
        }
    }

    @Test
    func dynamicMarkText_item_recognizedLevel_returnsNil() {
        #expect(dynamicMarkText(MXLDynamics.Item.mf) == nil)
    }
}
