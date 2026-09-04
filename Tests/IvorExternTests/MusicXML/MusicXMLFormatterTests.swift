// © 2026 John Gary Pusey (see LICENSE.md)

import Foundation
@testable import IvorExtern
import IvorModel
import IvorMusicXML
import IvorTiming
import IvorTuning
import Testing
import XestiNumbers
import XestiTools

struct MusicXMLFormatterTests {
}

// MARK: -

extension MusicXMLFormatterTests {
    @Test
    func format_compressed_producesZipArchive() throws {
        let work = Work(name: "Test", content: .standardBeat([], TempoMap()))
        let score = try MusicXML.Exporter().convert(work)
        let document = MusicXML.Document(content: .scorePartwise(score))

        let data = try MusicXML.Formatter().format(document, compressed: true)

        // A Zip archive's local file header always opens with this 4-byte
        // signature.
        #expect(data.prefix(4) == Data([0x50, 0x4b, 0x03, 0x04]))
    }

    @Test
    func format_invalidScore_throws() {
        // A `<score-part>` referenced by no `<part>` — a validation issue,
        // not something the schema itself catches.
        let partList = MXLPartList(items: [.scorePart(MXLScorePart(id: "P1", name: MXLPartName(value: "Orphan", text: MXLPartName.Text())))])
        let score = MusicXML.Score(partList: partList, parts: [])
        let document = MusicXML.Document(content: .scorePartwise(score))

        #expect(throws: (any Error).self) {
            try MusicXML.Formatter().format(document, compressed: false)
        }
    }

    @Test
    func format_minimalScore_nonEmpty() throws {
        let work = Work(name: "Test", content: .standardBeat([], TempoMap()))
        let score = try MusicXML.Exporter().convert(work)
        let document = MusicXML.Document(content: .scorePartwise(score))

        let data = try MusicXML.Formatter().format(document, compressed: false)

        #expect(!data.isEmpty)
    }

    @Test
    func format_roundTrip_preservesPartCount() throws {
        var table = NoteTable<BeatTime, Pitch>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: "C4")

        let work = Work(name: "Test", content: .standardBeat([Part(name: "Piano", noteTable: table)], TempoMap()))
        let score = try MusicXML.Exporter().convert(work)
        let document = MusicXML.Document(content: .scorePartwise(score))

        let data = try MusicXML.Formatter().format(document, compressed: false)
        let parsed = try MusicXML.Parser().parse(data, compressed: false)

        guard case let .scorePartwise(parsedScore) = parsed.content
        else {
            Issue.record("Expected a score-partwise document")

            return
        }

        #expect(parsedScore.parts.count == score.parts.count)
    }
}
