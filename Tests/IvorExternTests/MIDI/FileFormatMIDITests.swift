// © 2025–2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import IvorTiming
import IvorTuning
import Testing

struct FileFormatMIDITests {
}

// MARK: -

extension FileFormatMIDITests {
    @Test
    func midi_displayName() {
        #expect(FileFormat.midi.displayName == "Standard MIDI File")
    }

    @Test
    func midi_filenameExtensions() {
        #expect(FileFormat.midi.filenameExtensions == ["midi", "mid", "smf"])
    }

    @Test
    func midi_mimeTypes() {
        #expect(FileFormat.midi.mimeTypes == ["audio/midi", "audio/x-midi"])
    }

    @Test
    func midi_pitchNotations() {
        #expect(FileFormat.midi.pitchNotations == [.keyboard])
    }

    @Test
    func midi_preferredFilenameExtension() {
        #expect(FileFormat.midi.preferredFilenameExtension == "midi")
    }

    @Test
    func midi_preferredMIMEType() {
        #expect(FileFormat.midi.preferredMIMEType == "audio/midi")
    }

    @Test
    func midi_timeBases() {
        #expect(FileFormat.midi.timeBases == [.beat])
    }
}
