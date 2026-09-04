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
