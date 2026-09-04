// © 2025–2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import IvorTiming
import IvorTuning
import Testing

struct FileFormatJohnnySonicTests {
}

// MARK: -

extension FileFormatJohnnySonicTests {
    @Test
    func dkm_displayName() {
        #expect(FileFormat.dkm.displayName == "JohnnySonic Score File")
    }

    @Test
    func dkm_filenameExtensions() {
        #expect(FileFormat.dkm.filenameExtensions == ["dkm", "johnnysonic"])
    }

    @Test
    func dkm_pitchNotations() {
        #expect(FileFormat.dkm.pitchNotations == [.absolute, .keyboard])
    }

    @Test
    func dkm_preferredFilenameExtension() {
        #expect(FileFormat.dkm.preferredFilenameExtension == "dkm")
    }

    @Test
    func dkm_timeBases() {
        #expect(FileFormat.dkm.timeBases == [.beat])
    }
}
