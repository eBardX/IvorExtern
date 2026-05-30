// © 2025–2026 John Gary Pusey (see LICENSE.md)

import Foundation
@testable import IvorExtern
import IvorMIDI
import IvorModel
import IvorTiming
import Testing
import XestiTools

struct MIDIExporterTests {
}

// MARK: -

extension MIDIExporterTests {
    @Test
    func write_multipleWorks_throws() {
        let works = [Work(name: "A", content: .keyboardBeat([], TempoMap())),
                     Work(name: "B", content: .keyboardBeat([], TempoMap()))]

        #expect(throws: (any Error).self) {
            try MIDI.Exporter().write(works: works, as: .midi)
        }
    }

    @Test
    func write_singleWork_returnsRegularFile() throws {
        let work = Work(name: "Test", content: .keyboardBeat([], TempoMap()))
        let wrapper = try MIDI.Exporter().write(works: [work], as: .midi)

        #expect(wrapper.isRegularFile)
        #expect(wrapper.regularFileContents?.isEmpty == false)
    }

    @Test
    func write_unsupportedFormat_throws() {
        let work = Work(name: "Test", content: .keyboardBeat([], TempoMap()))

        #expect(throws: (any Error).self) {
            try MIDI.Exporter().write(works: [work], as: .abc)
        }
    }

    @Test
    func writableFileFormats_containsMIDI() {
        #expect(MIDI.Exporter().writableFileFormats.contains(.midi))
    }
}
