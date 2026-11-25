// © 2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import IvorModel
import IvorMXL
import IvorTiming
import IvorTuning
import Testing

struct MusicXMLExporterNotesTests {
}

// MARK: -

extension MusicXMLExporterNotesTests {
    @Test
    func makeSegmentItems_chord_laterTonesAreChordNotes() throws {
        let slices = exportSlices([(0, 1, "C4"), (0, 1, "E4"), (0, 1, "G4")], at: [0, 1])
        let slice = try #require(slices.first)
        let items = try MusicXML.Exporter.makeSegmentItems(slice: slice,
                                                           divisions: 1,
                                                           writer: musicXMLOrnamentWriter(Part(name: "P")))
        let notes = mxlNoteItems(items)

        #expect(notes.map(\.isChord) == [false, true, true])
        #expect(Set(notes.map(\.step)) == ["c", "e", "g"])
        #expect(notes.map(\.duration) == [4, 4, 4])
    }

    @Test
    func makeSegmentItems_emptySlice_isARest() throws {
        let slices = exportSlices([(1, 1, "C4")], at: [0, 1, 2])
        let slice = try #require(slices.first)
        let items = try MusicXML.Exporter.makeSegmentItems(slice: slice,
                                                           divisions: 2,
                                                           writer: musicXMLOrnamentWriter(Part(name: "P")))
        let notes = mxlNoteItems(items)

        #expect(notes.count == 1)
        #expect(notes.first?.step == "rest")
        #expect(notes.first?.duration == 8)
        #expect(notes.first?.ties.isEmpty == true)
    }

    @Test
    func makeSegmentItems_graceBefore_comesFirst() throws {
        var noteTable = NoteTable<BeatTime, Pitch>()

        try noteTable.insert(attack: beat(0),
                             duration: dur(1),
                             pitch: "C4",
                             ornamentation: .init(graceBefore: graceFigure("D4")))

        let part = Part(name: "P", noteTable: noteTable)
        let slice = try #require(ExportSlice.slices(of: ExportTone.tones(of: noteTable), at: [beat(0), beat(1)]).first)
        let items = try MusicXML.Exporter.makeSegmentItems(slice: slice,
                                                           divisions: 1,
                                                           writer: musicXMLOrnamentWriter(part, sliceStarts: [beat(0)]))

        #expect(items.count == 2)

        guard case let .note(grace) = items.first,
              case .graceNote = grace.content
        else { Issue.record("Expected the grace note first"); return }

        #expect(mxlNoteItems(items).map(\.step) == ["c"])
    }

    @Test
    func makeSegmentItems_singleNote() throws {
        let slices = exportSlices([(0, 1, "D4")], at: [0, 1])
        let slice = try #require(slices.first)
        let items = try MusicXML.Exporter.makeSegmentItems(slice: slice,
                                                           divisions: 4,
                                                           writer: musicXMLOrnamentWriter(Part(name: "P")))
        let notes = mxlNoteItems(items)

        #expect(notes.count == 1)
        #expect(notes.first?.isChord == false)
        #expect(notes.first?.step == "d")
        #expect(notes.first?.duration == 16)
        #expect(notes.first?.ties.isEmpty == true)
    }

    @Test
    func makeSegmentItems_toneAcrossABoundary_isTied() throws {
        let slices = exportSlices([(0, 2, "C4")], at: [0, 1, 2])
        let writer = musicXMLOrnamentWriter(Part(name: "P"))
        let first = try MusicXML.Exporter.makeSegmentItems(slice: slices[0], divisions: 1, writer: writer)
        let second = try MusicXML.Exporter.makeSegmentItems(slice: slices[1], divisions: 1, writer: writer)

        #expect(mxlNoteItems(first).first?.ties == [.start])
        #expect(mxlNoteItems(second).first?.ties == [.stop])
    }
}
