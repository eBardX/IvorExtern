// © 2026 John Gary Pusey (see LICENSE.md)

import Foundation
import IvorABC
@testable import IvorExtern
import IvorModel
import IvorTiming
import Testing

struct ABCFormatterTests {
}

// MARK: -

extension ABCFormatterTests {
    @Test
    func format_invalidTunebook_throws() throws {
        // No `K:` field — the validator requires one.
        let header: [ABCHeaderEntry] = try [.field(.referenceNumber(#require(ABCReferenceNumber(uintValue: 1)))),
                                            .field(.tuneTitle(#require(ABCText(stringValue: "Test"))))]
        let tune = try #require(ABCTune(header: header, body: []))
        let tunebook = try #require(ABCTunebook(fileHeader: [], tunes: [tune]))

        #expect(throws: (any Error).self) {
            try ABC.Formatter().format(tunebook)
        }
    }

    @Test
    func format_minimalTunebook_nonEmpty() throws {
        let work = Work(name: "Test", content: .standardBeat([], TempoMap()))
        let tune = try ABC.Exporter().convert(work)
        let tunebook = try #require(ABCTunebook(fileHeader: [], tunes: [tune]))

        let data = try ABC.Formatter().format(tunebook)

        #expect(!data.isEmpty)
    }

    @Test
    func format_roundTrip_preservesTuneCount() throws {
        let work = Work(name: "Test", content: .standardBeat([], TempoMap()))
        let tune = try ABC.Exporter().convert(work)
        let tunebook = try #require(ABCTunebook(fileHeader: [], tunes: [tune]))

        let data = try ABC.Formatter().format(tunebook)
        let (parsed, _) = try ABC.BaseParser().parse(data)

        #expect(parsed.tunes.count == tunebook.tunes.count)
    }
}
