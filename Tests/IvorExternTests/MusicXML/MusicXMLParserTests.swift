// © 2025–2026 John Gary Pusey (see LICENSE.md)

import Foundation
@testable import IvorExtern
import IvorMusicXML
import Testing

struct MusicXMLParserTests {
}

// MARK: -

extension MusicXMLParserTests {
    @Test
    func parse_invalidData_throws() {
        let data = Data([0x00, 0x01, 0x02, 0x03])

        #expect(throws: (any Error).self) {
            try MusicXML.Parser().parse(data,
                                        compressed: false)
        }
    }

    @Test
    func parse_validData_returnsDocument() throws {
        let musicXML = """
            <?xml version="1.0" encoding="UTF-8"?>
            <score-partwise version="4.0">
              <part-list>
                <score-part id="P1">
                  <part-name>Piano</part-name>
                </score-part>
              </part-list>
              <part id="P1">
                <measure number="1">
                  <note>
                    <pitch><step>C</step><octave>4</octave></pitch>
                    <duration>4</duration>
                    <type>quarter</type>
                  </note>
                </measure>
              </part>
            </score-partwise>
            """
        let data = Data(musicXML.utf8)

        let document = try MusicXML.Parser().parse(data,
                                                   compressed: false)

        guard case let .scorePartwise(score) = document.content
        else { Issue.record("Expected a score-partwise document"); return }

        #expect(score.parts.count == 1)
    }
}
