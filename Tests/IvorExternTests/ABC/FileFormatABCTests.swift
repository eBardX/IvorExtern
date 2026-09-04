// © 2025–2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import IvorTiming
import IvorTuning
import Testing

struct FileFormatABCTests {
}

// MARK: -

extension FileFormatABCTests {
    @Test
    func abc_displayName() {
        #expect(FileFormat.abc.displayName == "ABC File")
    }

    @Test
    func abc_filenameExtensions() {
        #expect(FileFormat.abc.filenameExtensions == ["abc"])
    }

    @Test
    func abc_mimeTypes() {
        #expect(FileFormat.abc.mimeTypes == ["text/vnd.abc"])
    }

    @Test
    func abc_pitchNotations() {
        #expect(FileFormat.abc.pitchNotations == [.standard])
    }

    @Test
    func abc_timeBases() {
        #expect(FileFormat.abc.timeBases == [.beat])
    }
}
