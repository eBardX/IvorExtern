// © 2025–2026 John Gary Pusey (see LICENSE.md)

import Foundation
@testable import IvorExtern
import IvorGMN
import IvorModel
import IvorTiming
import IvorTuning
import Testing
import XestiNumbers
import XestiTools

struct GuidoImporterTests {
}

// MARK: -

extension GuidoImporterTests {
    @Test
    func convert_instrumentTag_namesPart() throws {
        let data = Data("[ \\instr<\"Piano\"> c ]".utf8)
        let score = try Guido.Parser().parse(data)
        let work = try Guido.Importer().convert(score)

        guard case let .standardBeat(parts, _) = work.content
        else { Issue.record("Expected standardBeat content"); return }

        #expect(parts.map(\.name) == ["Piano"])
    }

    @Test
    func convert_instrumentTag_populatesInstrumentMap() throws {
        let data = Data("[ \\instr<\"Piano\"> c ]".utf8)
        let score = try Guido.Parser().parse(data)
        let work = try Guido.Importer().convert(score)

        guard case let .standardBeat(parts, _) = work.content
        else { Issue.record("Expected standardBeat content"); return }

        #expect(parts.first?.instrumentMap[.zero] == Instrument("Piano"))
    }

    @Test
    func convert_instrumentTagAfterLeadingRest_startsAtZero() throws {
        //
        // No note comes before the tag, so its instrument starts at zero, rather than leaving
        // the default instrument in effect for the rest.
        //
        let data = Data("[ _/4 \\instr<\"Piano\"> c ]".utf8)
        let score = try Guido.Parser().parse(data)
        let work = try Guido.Importer().convert(score)

        guard case let .standardBeat(parts, _) = work.content
        else { Issue.record("Expected standardBeat content"); return }

        #expect(parts.first?.instrumentMap.map(\.time) == [.zero])
        #expect(parts.first?.instrumentMap.instruments == [Instrument("Piano")])
    }

    @Test
    func convert_instrumentTagAfterNote_leavesEarlierNoteOnDefault() throws {
        //
        // The note before the tag has no instrument, so the default instrument is in effect
        // for it.
        //
        let data = Data("[ c/4 \\instr<\"Piano\"> d ]".utf8)
        let score = try Guido.Parser().parse(data)
        let work = try Guido.Importer().convert(score)

        guard case let .standardBeat(parts, _) = work.content
        else { Issue.record("Expected standardBeat content"); return }

        let instrumentMap = try #require(parts.first?.instrumentMap)

        #expect(instrumentMap.map(\.time) == [BeatTime(1)])
        #expect(instrumentMap[.zero] == instrumentMap.defaultInstrument)
        #expect(instrumentMap[BeatTime(1)] == Instrument("Piano"))
    }

    @Test
    func convert_instrumentTagInsideVariable_namesPart() throws {
        let data = Data("$intro = \"\\instr<\\\"Flute\\\"> c d\"; [ $intro e ]".utf8)
        let score = try Guido.Parser().parse(data)
        let work = try Guido.Importer().convert(score)

        guard case let .standardBeat(parts, _) = work.content
        else { Issue.record("Expected standardBeat content"); return }

        #expect(parts.map(\.name) == ["Flute"])
        #expect(parts.first?.instrumentMap[.zero] == Instrument("Flute"))
    }

    @Test
    func convert_multipleVoicesWithoutInstrumentTags_fallsBackToVoiceN() throws {
        let data = Data("{ [ c d ], [ \\instr<\"Bass\"> e f ], [ g a ] }".utf8)
        let score = try Guido.Parser().parse(data)
        let work = try Guido.Importer().convert(score)

        guard case let .standardBeat(parts, _) = work.content
        else { Issue.record("Expected standardBeat content"); return }

        #expect(parts.map(\.name) == ["Voice 1", "Bass", "Voice 3"])
    }

    @Test
    func convert_singleVoiceWithoutInstrumentTag_leavesPartUnnamed() throws {
        let data = Data("[ c d ]".utf8)
        let score = try Guido.Parser().parse(data)
        let work = try Guido.Importer().convert(score)

        guard case let .standardBeat(parts, _) = work.content
        else { Issue.record("Expected standardBeat content"); return }

        #expect(parts.map(\.name) == [""])
    }

    @Test
    func convert_tempoTag_populatesTempoMap() throws {
        let data = Data("[ \\tempo<\"Allegro\", \"1/4=144\"> c ]".utf8)
        let score = try Guido.Parser().parse(data)
        let work = try Guido.Importer().convert(score)

        guard case let .standardBeat(_, tempoMap) = work.content
        else { Issue.record("Expected standardBeat content"); return }

        #expect(!tempoMap.isEmpty)
    }

    @Test
    func read_emptyData_throws() {
        let wrapper = FileWrapper(regularFileWithContents: Data())

        #expect(throws: (any Error).self) {
            try Guido.Importer().read(from: wrapper, as: .gmn)
        }
    }

    @Test
    func read_footer_isRightsNoticeOrRemark() throws {
        let work = try readGuido(#"[ \footer<"© 1998 Acme"> \footer<"Engraved by hand"> c ]"#)

        #expect(work.info.rights == [RightsNotice(text: "© 1998 Acme")].compactMap(\.self))
        #expect(work.info.remarks == [Remark(text: "Engraved by hand", label: "footer")].compactMap(\.self))
    }

    @Test
    func read_instrument_isInstrumentNameExtra() throws {
        let work = try readGuido(#"[ \instr<"Flauto 1"> c ]"#)
        let part = try #require(standardBeatParts(of: work)?.first)
        let entry = try #require(part.instrumentMap.first)

        #expect(stringValue(entry.extras, .instrumentName) == "Flauto 1")
    }

    @Test
    func read_label_onlyLeadingBodilessLabelIsRemark() throws {
        let work = try readGuido(#"[ \label<"Theme"> c \label<"Later"> d ]"#)

        #expect(work.info.remarks == [Remark(text: "Theme", label: "label")].compactMap(\.self))
    }

    @Test
    func read_titleAndComposer_populateInfo() throws {
        let work = try readGuido(#"{ [ \title<"Sonata"> \title<"No. 1"> \composer<"J. Smith"> c ], [ \title<"Ignored"> e ] }"#)

        #expect(work.name == "Sonata: No. 1")
        #expect(work.info.title == "Sonata")
        #expect(work.info.subtitles == ["No. 1"])
        #expect(work.info.composers == ["J. Smith"])
    }

    @Test
    func read_unsupportedFormat_throws() {
        let wrapper = FileWrapper(regularFileWithContents: Data())

        #expect(throws: (any Error).self) {
            try Guido.Importer().read(from: wrapper, as: .midi)
        }
    }

    @Test
    func readableFileFormats_containsGMN() {
        #expect(Guido.Importer().readableFileFormats.contains(.gmn))
    }
}
