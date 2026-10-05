// © 2026 John Gary Pusey (see LICENSE.md)

import Foundation
@testable import IvorExtern
import IvorGMN
import IvorModel
import IvorTiming
import IvorTuning
import Testing
import XestiTools

struct GuidoInfoTests {
}

// MARK: -

extension GuidoInfoTests {
    @Test
    func read_footer_isRightsNoticeOrRemark() throws {
        let work = try _read(#"[ \footer<"© 1998 Acme"> \footer<"Engraved by hand"> c ]"#)

        #expect(work.info.rights == [RightsNotice(text: "© 1998 Acme")].compactMap(\.self))
        #expect(work.info.remarks == [Remark(text: "Engraved by hand", label: "footer")].compactMap(\.self))
    }

    @Test
    func read_instrument_isInstrumentNameExtra() throws {
        let work = try _read(#"[ \instr<"Flauto 1"> c ]"#)
        let part = try #require(standardBeatParts(of: work)?.first)
        let entry = try #require(part.instrumentMap.first)

        #expect(stringValue(entry.extras, .instrumentName) == "Flauto 1")
    }

    @Test
    func read_label_onlyLeadingBodilessLabelIsRemark() throws {
        let work = try _read(#"[ \label<"Theme"> c \label<"Later"> d ]"#)

        #expect(work.info.remarks == [Remark(text: "Theme", label: "label")].compactMap(\.self))
    }

    @Test
    func read_titleAndComposer_populateInfo() throws {
        let work = try _read(#"{ [ \title<"Sonata"> \title<"No. 1"> \composer<"J. Smith"> c ], [ \title<"Ignored"> e ] }"#)

        #expect(work.name == "Sonata: No. 1")
        #expect(work.info.title == "Sonata")
        #expect(work.info.subtitles == ["No. 1"])
        #expect(work.info.composers == ["J. Smith"])
    }

    @Test
    func write_instrumentNameExtra_namesInstrumentTag() throws {
        var instrumentMap = InstrumentMap<BeatTime>()

        instrumentMap.insert(time: .zero,
                             instrument: Instrument("Flute"),
                             extras: Extras(elements: [Extra(name: Extra.instrumentName.name, values: [.string("Flauto 1")])]))

        let part = Part<BeatTime, Pitch>(name: "", noteTable: NoteTable(), instrumentMap: instrumentMap)
        let score = try Guido.Exporter().convert(Work(name: "", content: .standardBeat([part], TempoMap())))

        #expect(instruments(in: score).map(\.instrumentName) == ["Flauto 1"])
    }

    @Test
    func write_info_writesLeadingTagsOfFirstVoice() throws {
        let score = try Guido.Exporter().convert(Work(name: "Sketch",
                                                      content: .standardBeat([Part(name: "", noteTable: NoteTable())], TempoMap()),
                                                      info: _sampleInfo()))
        let tags = try #require(score.voices.first).symbols.compactMap { symbol -> String? in
            switch symbol {
            case let .tag(.titleBlock(block)):
                "\(block.kind):\(block.text)"

            case let .tag(.text(text)):
                "\(text.kind):\(text.text)"

            default:
                nil
            }
        }

        #expect(tags == ["title:Aubade",
                         "title:Dawn Song",
                         "title:Morning Piece",
                         "composer:J. Smith",
                         "composer:A. Poet (lyricist)",
                         "footer:© 1998 Acme Line two",
                         "footer:Engraved by hand",
                         "label:Theme"])
    }

    @Test
    func roundTrip_info_preservesWhatGuidoCanHold() throws {
        let work = Work(name: "Aubade: Dawn Song: Morning Piece",
                        content: .standardBeat([Part(name: "", noteTable: NoteTable())], TempoMap()),
                        info: _sampleInfo())
        let recovered = try roundTrip(work,
                                      exporter: Guido.Exporter(),
                                      importer: Guido.Importer(),
                                      fileFormat: .gmn)
        let info = recovered.info

        #expect(recovered.name == work.name)
        #expect(info.title == "Aubade")
        #expect(info.subtitles == ["Dawn Song", "Morning Piece"])
        #expect(info.alternateTitles.isEmpty)
        #expect(info.parentWorkTitle == nil)
        #expect(info.dedication == nil)
        #expect(info.credits == [Credit(name: "J. Smith", role: .composer),
                                 Credit(name: "A. Poet (lyricist)", role: .composer)].compactMap(\.self))
        #expect(info.rights == [RightsNotice(text: "© 1998 Acme Line two")].compactMap(\.self))
        #expect(info.remarks == [Remark(text: "Engraved by hand", label: "footer"),
                                 Remark(text: "Theme", label: "label")].compactMap(\.self))
    }
}

// MARK: -

extension GuidoInfoTests {
    private func _read(_ gmn: String) throws -> Work {
        try Guido.Importer().convert(Guido.Parser().parse(Data(gmn.utf8)))
    }

    private func _sampleInfo() -> Work.Info {
        Work.Info(title: "Aubade",
                  subtitles: ["Dawn Song"],
                  alternateTitles: ["Morning Piece"],
                  parentWorkTitle: "Collected Pieces",
                  dedication: "To my teacher",
                  credits: [Credit(name: "J. Smith", role: .composer),
                            Credit(name: "A. Poet", role: .lyricist)].compactMap(\.self),
                  rights: [RightsNotice(text: "© 1998 Acme\nLine two")].compactMap(\.self),
                  remarks: [Remark(text: "Engraved by hand", label: "footer"),
                            Remark(text: "Theme", label: "label"),
                            Remark(text: "Dropped", label: "history")].compactMap(\.self))
    }
}
