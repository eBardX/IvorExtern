// © 2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import IvorModel
import IvorMXL
import Testing
import XestiTools

struct MusicXMLInfoFunctionsTests {
}

// MARK: -

extension MusicXMLInfoFunctionsTests {
    @Test
    func convertToMusicXMLCredits_subtitlesAndDedication_includeTitleFirst() {
        let credits = convertToMusicXMLCredits(title: "Aubade",
                                               subtitles: ["Dawn Song"],
                                               dedication: "To my teacher")

        #expect(credits.map(\.kind) == [["title"], ["subtitle"], ["dedication"]])
        #expect(credits.allSatisfy { $0.page == 1 })
    }

    @Test
    func convertToMusicXMLCredits_titleOnly_isEmpty() {
        #expect(convertToMusicXMLCredits(title: "Aubade",
                                         subtitles: [],
                                         dedication: nil).isEmpty)
    }

    @Test
    func convertToMusicXMLIdentification_emptyInfo_isNil() {
        #expect(convertToMusicXMLIdentification(Work.Info()) == nil)
    }

    @Test
    func convertToMusicXMLIdentification_info_mapsCreatorsRightsAndEncoders() throws {
        let info = Work.Info(credits: [Credit(name: "J. Smith", role: .composer),
                                       Credit(name: "T. Scribe", role: .transcriber)].compactMap(\.self),
                             rights: [RightsNotice(text: "© 1998 Acme", scope: .music)].compactMap(\.self),
                             remarks: [Remark(text: "Op. 2", label: RemarkLabel.workNumber)].compactMap(\.self))
        let identification = try #require(convertToMusicXMLIdentification(info))

        #expect(identification.creator == [MXLTypedText(value: "J. Smith", kind: "composer")])
        #expect(identification.rights == [MXLTypedText(value: "© 1998 Acme", kind: "music")])
        #expect(identification.encoding?.items == [.encoder(MXLTypedText(value: "T. Scribe"))])
        #expect(identification.miscellaneous == nil)
    }

    @Test
    func convertToMusicXMLIdentification_noRemarks_isNil() {
        #expect(convertToMusicXMLIdentification(remarks: []) == nil)
    }

    @Test
    func convertToMusicXMLIdentification_remarks_routedByLabel() throws {
        let remarks = [Remark(text: "From a fiddler", label: RemarkLabel.source),
                       Remark(text: "Second source", label: RemarkLabel.source),
                       Remark(text: "After Byrd", label: RemarkLabel.relation),
                       Remark(text: "Hand-entered", label: RemarkLabel.encodingDescription),
                       Remark(text: "A plain remark"),
                       Remark(text: "Wistful", label: "mood")].compactMap(\.self)
        let identification = try #require(convertToMusicXMLIdentification(remarks: remarks,
                                                                          alternateTitles: ["Morning Piece"]))

        #expect(identification.source == "From a fiddler")
        #expect(identification.relation == [MXLTypedText(value: "After Byrd")])
        #expect(identification.encoding?.items == [.encodingDescription("Hand-entered")])
        #expect(identification.miscellaneous?.field.map(\.name) == [MusicXML.alternateTitleFieldName,
                                                                    RemarkLabel.source,
                                                                    MusicXML.remarkFieldName,
                                                                    "mood"])
        #expect(identification.miscellaneous?.field.map(\.value) == ["Morning Piece",
                                                                     "Second source",
                                                                     "A plain remark",
                                                                     "Wistful"])
    }

    @Test
    func determineWorkInfo_movementTitle_isTitleUnderWorkTitle() throws {
        let score = try parseMusicXMLScore("""
            <?xml version="1.0" encoding="UTF-8"?>
            <score-partwise version="4.0">
              <work><work-number>Op. 2</work-number><work-title>Collected Pieces</work-title></work>
              <movement-title>Aubade</movement-title>
              <part-list><score-part id="P1"><part-name>Piano</part-name></score-part></part-list>
              <part id="P1"><measure number="1"/></part>
            </score-partwise>
            """)
        let info = determineWorkInfo(score)

        #expect(info.title == "Aubade")
        #expect(info.parentWorkTitle == "Collected Pieces")
        #expect(info.remarks == [Remark(text: "Op. 2", label: RemarkLabel.workNumber)].compactMap(\.self))
    }

    @Test
    func determineWorkInfo_workTitleOnly_isTitle() throws {
        let score = try parseMusicXMLScore("""
            <?xml version="1.0" encoding="UTF-8"?>
            <score-partwise version="4.0">
              <work><work-title>Aubade</work-title></work>
              <part-list><score-part id="P1"><part-name>Piano</part-name></score-part></part-list>
              <part id="P1"><measure number="1"/></part>
            </score-partwise>
            """)
        let info = determineWorkInfo(score)

        #expect(info.title == "Aubade")
        #expect(info.parentWorkTitle == nil)
    }
}
