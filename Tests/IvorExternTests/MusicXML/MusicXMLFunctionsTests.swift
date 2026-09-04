// © 2025–2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import IvorModel
import IvorMusicXML
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
    func convertToPan_clampsDegreesBeyondHardSides() {
        let sound = MXLSound(pan: 180)

        #expect(convertToPan(sound) == Pan(1))
    }

    @Test
    func convertToPan_midiInstrumentPan_takesPriorityOverDeprecatedSoundPan() {
        let midiInstrument = MXLMidiInstrument(id: "P1-I1",
                                               pan: -90)
        let sound = MXLSound(group: [MXLSound.Group(midiInstrument: midiInstrument)],
                             pan: 90)

        #expect(convertToPan(sound) == Pan(-1))
    }

    @Test
    func convertToPan_noPan_returnsNil() {
        #expect(convertToPan(MXLSound()) == nil)
    }

    @Test
    func convertToPan_usesDeprecatedSoundPan_whenNoMidiInstrumentPan() {
        let sound = MXLSound(pan: 45)

        #expect(convertToPan(sound) == Pan(0.5))
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
    func convertToTempo_metronome_dottedBeatUnit_scalesFactor() {
        let beatUnit = MXLBeatUnit(beatUnit: .quarter,
                                   dot: 1)
        let metronome = MXLMetronome(content: .beatUnit(beatUnit,
                                                        tied: [],
                                                        content: .perMinute(MXLPerMinute(value: "80"))))

        //
        // A dotted quarter is worth 1.5 quarters, so "dotted quarter = 80"
        // converts to 120 quarter notes per minute.
        //
        #expect(convertToTempo(metronome)?.uintValue == 120)
    }

    @Test
    func convertToTempo_metronome_metricModulation_returnsNil() {
        let metronome = MXLMetronome(content: .metronomeArrows(hasMetronomeArrows: true,
                                                               note: [],
                                                               relation: nil,
                                                               secondNote: []))

        #expect(convertToTempo(metronome) == nil)
    }

    @Test
    func convertToTempo_metronome_nonNumericPerMinute_returnsNil() {
        let beatUnit = MXLBeatUnit(beatUnit: .quarter,
                                   dot: 0)
        let metronome = MXLMetronome(content: .beatUnit(beatUnit,
                                                        tied: [],
                                                        content: .perMinute(MXLPerMinute(value: "ca. 120"))))

        #expect(convertToTempo(metronome) == nil)
    }

    @Test
    func convertToTempo_metronome_readsQuarterEqualsPerMinute() {
        let beatUnit = MXLBeatUnit(beatUnit: .quarter,
                                   dot: 0)
        let metronome = MXLMetronome(content: .beatUnit(beatUnit,
                                                        tied: [],
                                                        content: .perMinute(MXLPerMinute(value: "120"))))

        #expect(convertToTempo(metronome)?.uintValue == 120)
    }

    @Test
    func convertToTempo_metronome_scalesNonQuarterBeatUnit() {
        let beatUnit = MXLBeatUnit(beatUnit: .eighth,
                                   dot: 0)
        let metronome = MXLMetronome(content: .beatUnit(beatUnit,
                                                        tied: [],
                                                        content: .perMinute(MXLPerMinute(value: "160"))))

        //
        // "eighth = 160" is the same tempo as "quarter = 80".
        //
        #expect(convertToTempo(metronome)?.uintValue == 80)
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
    func determinePartName_singleNumeralNameWithGroupName_combinesGroupAndNumeral() {
        let scorePart = MXLScorePart(id: "P12",
                                     name: MXLPartName(value: "3",
                                                       text: .init()))

        #expect(determinePartName(scorePart, groupName: "Trombones") == "Trombones (3)")
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
    func determineWorkName_combinesWorkAndMovementTitles() {
        let score = MXLScorePartwise(work: MXLWork(title: "Symphony"),
                                     movementTitle: "Allegro",
                                     partList: MXLPartList())

        #expect(determineWorkName(score) == "Symphony: Allegro")
    }

    @Test
    func determineWorkName_noWorkOrMovementInfo_returnsEmptyString() {
        let score = MXLScorePartwise(partList: MXLPartList())

        #expect(determineWorkName(score).isEmpty)
    }

    @Test
    func determineWorkName_workTitleOnly_returnsWorkTitle() {
        let score = MXLScorePartwise(work: MXLWork(title: "Symphony"),
                                     partList: MXLPartList())

        #expect(determineWorkName(score) == "Symphony")
    }
}
