// © 2025–2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import IvorJohnnySonic
import IvorModel
import IvorTiming
import IvorTuning
import Testing
import XestiNumbers
import XestiTools

struct JohnnySonicFunctionsTests {
}

// MARK: -

extension JohnnySonicFunctionsTests {
    @Test
    func convertToBeatDuration() {
        let result = IvorExtern.convertToBeatDuration(2)

        #expect(result == BeatDuration(2))
    }

    @Test
    func convertToBeatTime() {
        let result = IvorExtern.convertToBeatTime(2)

        #expect(result == BeatTime(2))
    }

    @Test
    func convertToDynamic() throws {
        let expected = try #require(Dynamic(numberValue: Number(numerator: 1,
                                                                denominator: 2)))
        let dynamic = IvorExtern.convertToDynamic(5.0)

        #expect(dynamic == expected)
    }

    @Test
    func convertToFrequency_resolvedHertz_returnsFrequency() {
        #expect(convertToFrequency(440) == Frequency(440))
    }

    @Test
    func convertToInstrument_emptyName_returnsNil() {
        #expect(convertToInstrument("") == nil)
    }

    @Test
    func convertToInstrument_nonEmptyName_returnsInstrument() {
        #expect(convertToInstrument("Piano") == Instrument("Piano"))
    }

    @Test
    func convertToJohnnySonicBeat() {
        let result = IvorExtern.convertToJohnnySonicBeat(BeatTime(2))

        #expect(result == 2)
    }

    @Test
    func convertToJohnnySonicDuration() {
        let result = IvorExtern.convertToJohnnySonicDuration(BeatDuration(2))

        #expect(result == 2)
    }

    @Test
    func convertToJohnnySonicLocation() {
        let result = IvorExtern.convertToJohnnySonicLocation(Pan(0.5))

        #expect(result == 0.5)
    }

    @Test
    func convertToJohnnySonicPitch_frequency_negatesValue() {
        #expect(convertToJohnnySonicPitch(Frequency(440)) == -440)
    }

    @Test
    func convertToJohnnySonicPitch_noteNumber_returnsValue() {
        #expect(convertToJohnnySonicPitch(NoteNumber(60)) == 60)
    }

    @Test
    func convertToJohnnySonicTempo() {
        let result = IvorExtern.convertToJohnnySonicTempo(Tempo(120))

        #expect(result == 120)
    }

    @Test
    func convertToJohnnySonicVolume() throws {
        let dynamic = try #require(Dynamic(numberValue: Number(numerator: 1,
                                                               denominator: 2)))
        let result = IvorExtern.convertToJohnnySonicVolume(dynamic)

        #expect(result == 5)
    }

    @Test
    func convertToNoteNumber_negativePitch_returnsNil() {
        #expect(convertToNoteNumber(-1) == nil)
    }

    @Test
    func convertToNoteNumber_nonNegativePitch_roundsToNearestInteger() {
        #expect(convertToNoteNumber(60.4) == NoteNumber(60))
    }

    @Test
    func convertToPan() {
        let result = IvorExtern.convertToPan(0.5)

        #expect(result == Pan(0.5))
    }

    @Test
    func convertToTempo_nonFiniteOrNonPositiveBPM_returnsDefault() {
        #expect(convertToTempo(0) == .default)
        #expect(convertToTempo(-10) == .default)
        #expect(convertToTempo(.nan) == .default)
    }

    @Test
    func convertToTempo_validBPM_roundsToNearestInteger() {
        #expect(convertToTempo(120.4) == Tempo(120))
    }

    @Test
    func determineWorkName_commentWithoutWorkPrefix_returnsEmptyString() {
        let score = JohnnySonic.Score(commands: [.comment("| Not a work |")])

        #expect(determineWorkName(score).isEmpty)
    }

    @Test
    func determineWorkName_extractsNameFromWorkComment() {
        let score = JohnnySonic.Score(commands: [.comment("+-------+"),
                                                 .comment("| Work: My Piece |"),
                                                 .comment("+-------+")])

        #expect(determineWorkName(score) == "My Piece")
    }
}
