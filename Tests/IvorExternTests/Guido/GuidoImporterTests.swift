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
    func convert_failingWalk_wrapsErrorInConvertFailure() {
        let rest = GMNRest(duration: GMNDuration(milliseconds: 500))
        let score = Guido.Score(variables: [],
                                voices: [Guido.Voice(symbols: [.rest(rest)])])

        do {
            _ = try Guido.Importer().convert(score)

            Issue.record("Expected convert to throw")
        } catch {
            guard case let .convertFailure(cause) = error
            else { Issue.record("Expected convertFailure, got \(error)"); return }

            #expect(cause != nil)
        }
    }

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
    func convert_instrumentTag_populatesInstrumentTable() throws {
        let data = Data("[ \\instr<\"Piano\"> c ]".utf8)
        let score = try Guido.Parser().parse(data)
        let work = try Guido.Importer().convert(score)

        guard case let .standardBeat(parts, _) = work.content
        else { Issue.record("Expected standardBeat content"); return }

        #expect(parts.first?.instrumentTable[.zero] == Instrument("Piano"))
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

        #expect(parts.first?.instrumentTable.map(\.time) == [.zero])
        #expect(parts.first?.instrumentTable.instruments == [Instrument("Piano")])
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

        let instrumentTable = try #require(parts.first?.instrumentTable)

        #expect(instrumentTable.map(\.time) == [BeatTime(1)])
        #expect(instrumentTable[.zero] == instrumentTable.defaultInstrument)
        #expect(instrumentTable[BeatTime(1)] == Instrument("Piano"))
    }

    @Test
    func convert_instrumentTagInsideVariable_namesPart() throws {
        let data = Data("$intro = \"\\instr<\\\"Flute\\\"> c d\"; [ $intro e ]".utf8)
        let score = try Guido.Parser().parse(data)
        let work = try Guido.Importer().convert(score)

        guard case let .standardBeat(parts, _) = work.content
        else { Issue.record("Expected standardBeat content"); return }

        #expect(parts.map(\.name) == ["Flute"])
        #expect(parts.first?.instrumentTable[.zero] == Instrument("Flute"))
    }

    @Test
    func convert_intensityChange_isAStep() throws {
        let part = try #require(standardBeatParts(of: readGuido(#"[ \intens<"p"> c d \intens<"f"> e ]"#))?.first)

        #expect(part.dynamicMap.map(\.time) == [.zero, BeatTime(2), BeatTime(2)])
        #expect(part.dynamicMap.map(\.dynamic) == [.p, .p, .f])
    }

    @Test
    func convert_intensityWithoutACanonicalLevel_keepsItsMark() throws {
        let part = try #require(standardBeatParts(of: readGuido(#"[ \intens<"p"> c \intens<"sfz"> d ]"#))?.first)
        let marks = part.dynamicMap.map { stringValue($0.extras, .dynamicMark) }

        #expect(part.dynamicMap.map(\.time) == [.zero, BeatTime(1)])
        #expect(part.dynamicMap.map(\.dynamic) == [.p, .p])
        #expect(marks == [nil, "sfz"])
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
    func convert_noPedalTags_hasNoPedals() throws {
        #expect(try guidoPedalPart("[ c d e f ]").pedals.isEmpty)
    }

    @Test
    func convert_pedalOnAndOff_populateSustainTable() throws {
        let part = try guidoPedalPart("[ \\pedalOn c d \\pedalOff e f ]")

        #expect(Array(part.pedals.keys) == [.sustain])
        #expect(part.pedals[.sustain]?.map(\.time) == [0, 2])
        #expect(part.pedals[.sustain]?.map(\.level) == [.on, .off])
    }

    @Test
    func convert_rampTag_leavesAGlideBetweenItsEndpoints() throws {
        let part = try #require(standardBeatParts(of: readGuido(#"[ \cresc( c d ) e ]"#))?.first)

        #expect(part.dynamicMap.map(\.time) == [.zero, BeatTime(2)])
        #expect(part.dynamicMap.map(\.dynamic) == [.mp, .mf])
    }

    @Test
    func convert_repedal_keepsOffThenOn() throws {
        let part = try guidoPedalPart("[ \\pedalOn c d \\pedalOff \\pedalOn e \\pedalOff ]")

        #expect(part.pedals[.sustain]?.map(\.time) == [0, 2, 2, 3])
        #expect(part.pedals[.sustain]?.map(\.level) == [.on, .off, .on, .off])
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
    func convert_tempoChange_isAStep() throws {
        let work = try readGuido(#"[ \tempo<"Fast", "1/4=120"> c \tempo<"Slow", "1/4=60"> d ]"#)

        guard case let .standardBeat(_, tempoMap) = work.content
        else { Issue.record("Expected standardBeat content"); return }

        #expect(tempoMap.map(\.beatTime) == [.zero, BeatTime(1), BeatTime(1)])
        #expect(tempoMap.map(\.tempo.uintValue) == [120, 120, 60])
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
        let entry = try #require(part.instrumentTable.first)

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
