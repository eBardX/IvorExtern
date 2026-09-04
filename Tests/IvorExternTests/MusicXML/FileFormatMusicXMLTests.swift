// © 2025–2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import IvorTiming
import IvorTuning
import Testing

struct FileFormatMusicXMLTests {
}

// MARK: -

extension FileFormatMusicXMLTests {
    @Test
    func musicXML_displayName() {
        #expect(FileFormat.musicXML.displayName == "MusicXML Document")
    }

    @Test
    func musicXML_filenameExtensions() {
        #expect(FileFormat.musicXML.filenameExtensions == ["musicxml", "xml"])
    }

    @Test
    func musicXML_mimeTypes() {
        #expect(FileFormat.musicXML.mimeTypes == ["application/vnd.recordare.musicxml+xml",
                                                  "application/musicxml+xml"])
    }

    @Test
    func musicXML_pitchNotations() {
        #expect(FileFormat.musicXML.pitchNotations == [.standard])
    }

    @Test
    func musicXML_timeBases() {
        #expect(FileFormat.musicXML.timeBases == [.beat])
    }

    @Test
    func mxl_displayName() {
        #expect(FileFormat.mxl.displayName == "Compressed MusicXML Document")
    }

    @Test
    func mxl_filenameExtensions() {
        #expect(FileFormat.mxl.filenameExtensions == ["mxl"])
    }

    @Test
    func mxl_mimeTypes() {
        #expect(FileFormat.mxl.mimeTypes == ["application/vnd.recordare.musicxml",
                                             "application/musicxml+zip"])
    }

    @Test
    func mxl_pitchNotations() {
        #expect(FileFormat.mxl.pitchNotations == [.standard])
    }

    @Test
    func mxl_timeBases() {
        #expect(FileFormat.mxl.timeBases == [.beat])
    }
}
