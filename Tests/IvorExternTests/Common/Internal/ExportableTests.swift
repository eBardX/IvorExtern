// © 2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import Testing

struct ExportableTests {
}

// MARK: -

extension ExportableTests {
    @Test
    func exporter_everyFormat_writesItsOwnFileFormats() {
        let candidates: [any Exportable] = [ABC(), Guido(), JohnnySonic(), MIDI(), MusicXML()]
        let formats = candidates.map { $0.exporter.writableFileFormats }

        #expect(formats == [[.abc], [.gmn], [.dkm], [.midi], [.musicXML, .mxl]])
    }
}
