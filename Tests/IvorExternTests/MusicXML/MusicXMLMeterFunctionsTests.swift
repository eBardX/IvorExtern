// © 2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import IvorModel
import IvorMXL
import Testing
import XestiTools

struct MusicXMLMeterFunctionsTests {
}

// MARK: -

extension MusicXMLMeterFunctionsTests {
    @Test(arguments: [("x", "4"), ("3+", "4"), ("3", "0"), ("0", "4")])
    func convertToMeter_invalidField_returnsNil(_ beats: String,
                                                _ beatType: String) {
        let time = MXLTime(content: .timeSignature([MXLTimeSignature(beats: beats, beatType: beatType)],
                                                   interchangeable: nil))

        #expect(convertToMeter(time) == nil)
    }

    @Test
    func convertToMeter_senzaMisura_isFree() {
        #expect(convertToMeter(MXLTime(content: .senzaMisura(""))) == .free)
    }

    @Test(arguments: [([("6", "8")], "6/8"),
                      ([("3+2", "8")], "3+2/8"),
                      ([("2 + 2 + 3", "8")], "2+2+3/8"),
                      ([("3", "4"), ("3", "8")], "6+3/8"),
                      ([("3", "8"), ("2", "8")], "3+2/8"),
                      ([("4", "3")], "4/3")])
    func convertToMeter_timeSignature_readsGroupsOverOneBeatType(_ signatures: [(String, String)],
                                                                 _ expected: String) {
        let time = MXLTime(content: .timeSignature(signatures.map { MXLTimeSignature(beats: $0.0, beatType: $0.1) },
                                                   interchangeable: nil))

        #expect(convertToMeter(time) == meter(expected))
    }

    @Test
    func convertToMeterExtras_commonOrCut_givesAMeterSymbol() {
        let common = MXLTime(content: .timeSignature([MXLTimeSignature(beats: "4", beatType: "4")], interchangeable: nil),
                             symbol: .common)
        let cut = MXLTime(content: .timeSignature([MXLTimeSignature(beats: "2", beatType: "2")], interchangeable: nil),
                          symbol: .cut)

        #expect(stringValue(convertToMeterExtras(common), .meterSymbol) == "common")
        #expect(stringValue(convertToMeterExtras(cut), .meterSymbol) == "cut")
    }

    @Test
    func convertToMeterExtras_otherSymbol_returnsNil() {
        let time = MXLTime(content: .timeSignature([MXLTimeSignature(beats: "3", beatType: "4")], interchangeable: nil),
                           symbol: .singleNumber)

        #expect(convertToMeterExtras(time) == nil)
    }

    @Test
    func convertToMusicXMLTime_free_isSenzaMisura() {
        #expect(convertToMusicXMLTime(.free, nil).content == .senzaMisura(""))
    }

    @Test
    func convertToMusicXMLTime_groupedMeter_joinsItsGroups() {
        let time = convertToMusicXMLTime(meter("2+2+3/8"), nil)

        #expect(time.content == .timeSignature([MXLTimeSignature(beats: "2+2+3", beatType: "8")], interchangeable: nil))
        #expect(time.symbol == nil)
    }

    @Test
    func convertToMusicXMLTime_matchingSymbol_isDrawn() {
        #expect(convertToMusicXMLTime(meter("4/4"), meterSymbolExtras("common")).symbol == .common)
        #expect(convertToMusicXMLTime(meter("2/2"), meterSymbolExtras("cut")).symbol == .cut)
    }

    @Test
    func convertToMusicXMLTime_mismatchedSymbol_isDropped() {
        #expect(convertToMusicXMLTime(meter("4/2"), meterSymbolExtras("common")).symbol == nil)
    }
}
