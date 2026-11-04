// © 2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import Testing

struct ImportableTests {
}

// MARK: -

extension ImportableTests {
    @Test
    func importer_everyFormat_readsItsOwnFileFormats() {
        let candidates: [any Importable] = [ABC(), Guido(), JohnnySonic(), MIDI(), MusicXML()]
        let formats = candidates.map { $0.importer.readableFileFormats }

        #expect(formats == [[.abc], [.gmn], [.dkm], [.midi], [.musicXML, .mxl]])
    }
}
