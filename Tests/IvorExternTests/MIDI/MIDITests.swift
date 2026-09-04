// © 2025–2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import Testing

struct MIDITests {
}

// MARK: -

extension MIDITests {
    @Test
    func exporter_writableFileFormats() {
        let subject = MIDI()

        #expect(subject.exporter.writableFileFormats == [.midi])
    }

    @Test
    func importer_readableFileFormats() {
        let subject = MIDI()

        #expect(subject.importer.readableFileFormats == [.midi])
    }
}
