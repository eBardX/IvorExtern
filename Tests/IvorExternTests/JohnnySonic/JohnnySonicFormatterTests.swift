// © 2025–2026 John Gary Pusey (see LICENSE.md)

import Foundation
@testable import IvorExtern
import IvorJohnnySonic
import IvorModel
import IvorTiming
import Testing

struct JohnnySonicFormatterTests {
}

// MARK: -

extension JohnnySonicFormatterTests {
    @Test
    func format_invalidScore_throws() {
        let score = JohnnySonic.Score(commands: [.pulseLine(DKMPulseLine(startBeat: 9_000.0,
                                                                         channel: .both))])

        #expect(throws: (any Error).self) {
            try JohnnySonic.Formatter().format(score)
        }
    }

    @Test
    func format_minimalScore_nonEmpty() throws {
        let score = JohnnySonic.Score(commands: [.end])

        let data = try JohnnySonic.Formatter().format(score)

        #expect(!data.isEmpty)
    }

    @Test
    func format_roundTrip_preservesCommandCount() throws {
        let work = Work(name: "Test",
                        content: .keyboardBeat([], TempoMap()))
        let score = try JohnnySonic.Exporter().convert(work)
        let data = try JohnnySonic.Formatter().format(score)

        let parsed = try JohnnySonic.Parser().parse(data)

        #expect(parsed.commands.count == score.commands.count)
    }
}
