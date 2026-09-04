// © 2025–2026 John Gary Pusey (see LICENSE.md)

import Foundation
@testable import IvorExtern
import IvorGuido
import Testing

struct GuidoParserTests {
}

// MARK: -

extension GuidoParserTests {
    @Test
    func parse_invalidData_throws() {
        let data = Data([0x00, 0x01, 0x02, 0x03])

        #expect(throws: (any Error).self) {
            try Guido.Parser().parse(data)
        }
    }

    @Test
    func parse_validData_returnsScore() throws {
        let data = Data("[ c d e ]".utf8)

        let score = try Guido.Parser().parse(data)

        #expect(score.voices.count == 1)
    }
}
