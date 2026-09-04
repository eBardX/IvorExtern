// © 2026 John Gary Pusey (see LICENSE.md)

import Foundation
@testable import IvorExtern
import IvorGuido
import IvorModel
import IvorTiming
import IvorTuning
import Testing
import XestiNumbers
import XestiTools

struct GuidoFormatterTests {
}

// MARK: -

extension GuidoFormatterTests {
    @Test
    func format_invalidScore_throws() {
        // A body-less `\title` — `rangeSetting == .no` — but written with a
        // body, which the validator flags as `unexpectedTagBody`.
        let symbol = GMNSymbol.tag(.titleBlock(GMNTitleBlock(kind: .title,
                                                             text: "Test",
                                                             body: [.rest(GMNRest(duration: nil))])))
        let score = GMNScore(variables: [], voices: [GMNVoice(symbols: [symbol])])

        #expect(throws: (any Error).self) {
            try Guido.Formatter().format(score)
        }
    }

    @Test
    func format_minimalScore_nonEmpty() throws {
        let work = Work(name: "Test", content: .standardBeat([], TempoMap()))
        let score = try Guido.Exporter().convert(work)

        let data = try Guido.Formatter().format(score)

        #expect(!data.isEmpty)
    }

    @Test
    func format_roundTrip_preservesVoiceCount() throws {
        var table = NoteTable<BeatTime, Pitch>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: "C4")

        let work = Work(name: "Test", content: .standardBeat([Part(name: "", noteTable: table)], TempoMap()))
        let score = try Guido.Exporter().convert(work)

        let data = try Guido.Formatter().format(score)
        let parsed = try Guido.Parser().parse(data)

        #expect(parsed.voices.count == score.voices.count)
    }
}
