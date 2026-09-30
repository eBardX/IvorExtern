// © 2026 John Gary Pusey (see LICENSE.md)

import Foundation
import IvorDKM
@testable import IvorExtern
import Testing

struct JohnnySonicParserTests {
}

// MARK: -

extension JohnnySonicParserTests {
    @Test
    func parse_invalidData_throws() {
        let data = Data([0x00, 0x01, 0x02, 0x03])

        #expect(throws: (any Error).self) {
            try JohnnySonic.Parser().parse(data)
        }
    }

    @Test
    func parse_validData_returnsScore() throws {
        let original = JohnnySonic.Score(commands: [.end])
        let data = try JohnnySonic.Formatter().format(original)

        let score = try JohnnySonic.Parser().parse(data)

        #expect(score.commands.contains(.end))
    }
}
