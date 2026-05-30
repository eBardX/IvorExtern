// © 2025–2026 John Gary Pusey (see LICENSE.md)

import Foundation
@testable import IvorExtern
import IvorMIDI
import Testing
import XestiTools

struct MIDIParserTests {
}

// MARK: -

extension MIDIParserTests {
    @Test
    func parse_invalidData_throws() {
        let data = Data([0x00, 0x01, 0x02, 0x03])

        #expect(throws: (any Error).self) {
            try MIDI.Parser().parse(data)
        }
    }

    @Test
    func parse_validData_returnsSequence() throws {
        let track = SMFTrack(events: [.meta(.zero, .endOfTrack)])
        let original = SMFSequence(format: .format1,
                                   division: .metrical(SMFTickRate(480)),
                                   tracks: [track])
        let data = try MIDI.Formatter().format(original)

        let parsed = try MIDI.Parser().parse(data)

        #expect(parsed.tracks.count == 1)
    }
}
