// © 2025–2026 John Gary Pusey (see LICENSE.md)

import Foundation
@testable import IvorExtern
import IvorMIDI
import Testing
import XestiTools

struct MIDIImporterTests {
}

// MARK: -

extension MIDIImporterTests {
    @Test
    func read_emptyData_throws() {
        let wrapper = FileWrapper(regularFileWithContents: Data())

        #expect(throws: (any Error).self) {
            try MIDI.Importer().read(from: wrapper, as: .midi)
        }
    }

    @Test
    func read_unsupportedFormat_throws() {
        let wrapper = FileWrapper(regularFileWithContents: Data())

        #expect(throws: (any Error).self) {
            try MIDI.Importer().read(from: wrapper, as: .abc)
        }
    }

    @Test
    func read_validData_returnsWork() throws {
        let track = SMFTrack(events: [.meta(.zero, .endOfTrack)])
        let sequence = SMFSequence(format: .format1,
                                   division: .metrical(SMFTickRate(480)),
                                   tracks: [track])
        let data = try MIDI.Formatter().format(sequence)
        let wrapper = FileWrapper(regularFileWithContents: data)

        let works = try MIDI.Importer().read(from: wrapper, as: .midi)

        #expect(works.count == 1)
    }

    @Test
    func readableFileFormats_containsMIDI() {
        #expect(MIDI.Importer().readableFileFormats.contains(.midi))
    }
}
