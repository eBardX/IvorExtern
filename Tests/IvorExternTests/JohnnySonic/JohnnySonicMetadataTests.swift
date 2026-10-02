// © 2026 John Gary Pusey (see LICENSE.md)

import Foundation
import IvorDKM
@testable import IvorExtern
import IvorModel
import IvorTiming
import IvorTuning
import Testing
import XestiNumbers
import XestiTools

struct JohnnySonicMetadataTests {
}

// MARK: -

extension JohnnySonicMetadataTests {
    @Test
    func determineWorkMetadata_plainComments_areRemarksExceptBanners() {
        let score = JohnnySonic.Score(commands: [.comment("+------------+"),
                                                 .comment("| Work: Song |"),
                                                 .comment("+------------+"),
                                                 .comment("st dur vol loc sPit ePit Inst"),
                                                 .comment("second line"),
                                                 .end,
                                                 .comment("19-TET"),
                                                 .comment("")])
        let metadata = determineWorkMetadata(score)

        #expect(metadata.remarks == [Remark(text: "st dur vol loc sPit ePit Inst\nsecond line"),
                                     Remark(text: "19-TET")].compactMap(\.self))
    }

    @Test
    func convertToJohnnySonicComments_multiLineText_usesContinuationLines() {
        let metadata = Work.Metadata(title: "Aubade",
                                     credits: [Credit(name: "J. Smith", role: .composer)].compactMap(\.self),
                                     rights: [RightsNotice(text: "© 1998 Acme\n\nAll rights reserved")].compactMap(\.self),
                                     remarks: [Remark(text: "Wistful", label: "mood")].compactMap(\.self))
        let comments = convertToJohnnySonicComments(metadata)

        #expect(comments == ["Title: Aubade",
                             "Credit (composer): J. Smith",
                             "Rights: © 1998 Acme",
                             "  ",
                             "  All rights reserved",
                             "Remark (mood): Wistful"])
    }

    @Test
    func roundTrip_metadata_preservesWork() throws {
        var table = NoteTable<BeatTime, NoteNumber>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: NoteNumber(60))

        let metadata = Work.Metadata(title: "Aubade",
                                     subtitles: ["Dawn Song"],
                                     alternateTitles: ["Morning Piece"],
                                     parentWorkTitle: "Collected Pieces",
                                     credits: [Credit(name: "J. Smith", role: .composer),
                                               Credit(name: "Anon.")].compactMap(\.self),
                                     rights: [RightsNotice(text: "© 1998 Acme\nLine two", scope: .music)].compactMap(\.self),
                                     remarks: [Remark(text: "A plain remark"),
                                               Remark(text: "First\n\nSecond", label: "history")].compactMap(\.self))
        let work = Work(name: "Sketch",
                        content: .keyboardBeat([Part(name: "Piano", noteTable: table)], TempoMap()),
                        metadata: metadata)
        let recovered = try roundTrip(work,
                                      exporter: JohnnySonic.Exporter(),
                                      importer: JohnnySonic.Importer(),
                                      fileFormat: .dkm)

        #expect(recovered.name == "Sketch")
        #expect(recovered.metadata == metadata)
    }
}
