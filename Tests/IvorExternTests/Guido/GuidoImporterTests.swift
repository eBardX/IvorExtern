// © 2025–2026 John Gary Pusey (see LICENSE.md)

import Foundation
@testable import IvorExtern
import IvorModel
import IvorTiming
import Testing
import XestiTools

struct GuidoImporterTests {
}

// MARK: -

extension GuidoImporterTests {
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
    func convert_instrumentTag_namesPart() throws {
        let data = Data("[ \\instr<\"Piano\"> c ]".utf8)
        let score = try Guido.Parser().parse(data)
        let work = try Guido.Importer().convert(score)

        guard case let .standardBeat(parts, _) = work.content
        else { Issue.record("Expected standardBeat content"); return }

        #expect(parts.map(\.name) == ["Piano"])
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
