// © 2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import IvorModel
import IvorMXL
import Testing

struct MusicXMLImporterNoteMarksTests {
}

// MARK: -

extension MusicXMLImporterNoteMarksTests {
    @Test
    func init_defaults() {
        let marks = MusicXML.Importer.NoteMarks()

        #expect(marks.arpeggioDirection == nil)
        #expect(marks.arpeggioNumber == 0)
        #expect(marks.fermata == nil)
        #expect(!marks.hasCaesura)
        #expect(!marks.hasNonArpeggiate)
        #expect(!marks.isArpeggiated)
        #expect(marks.ornament == nil)
        #expect(marks.slurStops.isEmpty)
        #expect(marks.tremolo == nil)
        #expect(marks.wavyLineStarts.isEmpty)
        #expect(marks.wavyLineStops.isEmpty)
    }

    @Test
    func mutation_updatesValues() throws {
        var marks = MusicXML.Importer.NoteMarks()
        let trill = try #require(BeatNotes.Ornament(sign: .trill, partner: .step(.above, written: nil)))

        marks.arpeggioDirection = .up
        marks.arpeggioNumber = 2
        marks.fermata = .long
        marks.hasCaesura = true
        marks.isArpeggiated = true
        marks.ornament = trill
        marks.slurStops = [1]
        marks.wavyLineStarts = [1, 2]

        #expect(marks.arpeggioDirection == .up)
        #expect(marks.arpeggioNumber == 2)
        #expect(marks.fermata == .long)
        #expect(marks.hasCaesura)
        #expect(marks.isArpeggiated)
        #expect(marks.ornament == trill)
        #expect(marks.slurStops == [1])
        #expect(marks.wavyLineStarts == [1, 2])
    }
}
