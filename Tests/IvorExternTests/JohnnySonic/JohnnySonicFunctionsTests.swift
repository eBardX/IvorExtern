// © 2025–2026 John Gary Pusey (see LICENSE.md)

import Foundation
import IvorDKM
@testable import IvorExtern
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

        #expect(result == dur(1, 2))
    }

    @Test
    func convertToBeatTime() {
        let result = IvorExtern.convertToBeatTime(2)

        #expect(result == beat(1, 2))
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
        let result = IvorExtern.convertToJohnnySonicBeat(beat(1, 2))

        // Half a whole note is two JohnnySonic (quarter-note) beats.
        #expect(result == 2)
    }

    @Test
    func convertToJohnnySonicComments_multiLineText_usesContinuationLines() {
        let info = Work.Info(title: "Aubade",
                             dedication: "To my teacher\nwith thanks",
                             credits: [Credit(name: "J. Smith", role: .composer)].compactMap(\.self),
                             rights: [RightsNotice(text: "© 1998 Acme\n\nAll rights reserved")].compactMap(\.self),
                             remarks: [Remark(text: "Wistful", label: "mood")].compactMap(\.self))
        let comments = convertToJohnnySonicComments(info)

        #expect(comments == ["Title: Aubade",
                             "Dedication: To my teacher",
                             "  with thanks",
                             "Credit (composer): J. Smith",
                             "Rights: © 1998 Acme",
                             "  ",
                             "  All rights reserved",
                             "Remark (mood): Wistful"])
    }

    @Test
    func convertToJohnnySonicDuration() {
        let result = IvorExtern.convertToJohnnySonicDuration(dur(1, 2))

        #expect(result == 2)
    }

    @Test
    func convertToJohnnySonicLocation() {
        let result = IvorExtern.convertToJohnnySonicLocation(Pan(horizontal: 45))

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

        #expect(result == Pan(horizontal: 45))
    }

    @Test
    func convertToTempo_nonFiniteOrNonPositiveBPM_returnsDefault() {
        #expect(convertToTempo(0.0) == .default)
        #expect(convertToTempo(-10.0) == .default)
        #expect(convertToTempo(.nan) == .default)
    }

    @Test
    func convertToTempo_validBPM_roundsToNearestInteger() {
        #expect(convertToTempo(120.4) == Tempo(120))
    }

    @Test
    func determineWorkInfo_plainComments_areRemarksExceptBanners() {
        let score = JohnnySonic.Score(commands: [.comment("+------------+"),
                                                 .comment("| Work: Song |"),
                                                 .comment("+------------+"),
                                                 .comment("st dur vol loc sPit ePit Inst"),
                                                 .comment("second line"),
                                                 .end,
                                                 .comment("19-TET"),
                                                 .comment("")])
        let info = determineWorkInfo(score)

        #expect(info.remarks == [Remark(text: "st dur vol loc sPit ePit Inst\nsecond line"),
                                 Remark(text: "19-TET")].compactMap(\.self))
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
