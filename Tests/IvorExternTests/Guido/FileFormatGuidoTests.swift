// © 2025–2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import IvorTiming
import IvorTuning
import Testing

struct FileFormatGuidoTests {
}

// MARK: -

extension FileFormatGuidoTests {
    @Test
    func gmn_displayName() {
        #expect(FileFormat.gmn.displayName == "Guido Score File")
    }

    @Test
    func gmn_filenameExtensions() {
        #expect(FileFormat.gmn.filenameExtensions == ["gmn"])
    }

    @Test
    func gmn_mimeTypes() {
        #expect(FileFormat.gmn.mimeTypes.isEmpty)
    }

    @Test
    func gmn_pitchNotations() {
        #expect(FileFormat.gmn.pitchNotations == [.standard])
    }

    @Test
    func gmn_timeBases() {
        #expect(FileFormat.gmn.timeBases == [.beat])
    }
}
