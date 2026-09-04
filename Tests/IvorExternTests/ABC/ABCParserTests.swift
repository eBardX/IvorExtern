// © 2025–2026 John Gary Pusey (see LICENSE.md)

import Foundation
import IvorABC
@testable import IvorExtern
import Testing

struct ABCParserTests {
}

// MARK: -

extension ABCParserTests {
    @Test
    func parse_invalidData_throws() {
        let data = Data([0x00, 0x01, 0x02, 0x03])

        #expect(throws: (any Error).self) {
            try ABC.Parser().parse(data)
        }
    }

    @Test
    func parse_validData_returnsTunebook() throws {
        let abc = """
            X:1
            T:Test Tune
            L:1/4
            K:C
            C D E F|
            """
        let data = Data(abc.utf8)

        let tunebook = try ABC.Parser().parse(data)

        #expect(tunebook.tunes.count == 1)
    }
}
