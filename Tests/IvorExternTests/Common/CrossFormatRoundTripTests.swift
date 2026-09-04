// © 2026 John Gary Pusey (see LICENSE.md)

import Foundation
@testable import IvorExtern
import IvorModel
import IvorTiming
import IvorTuning
import Testing
import XestiNumbers

// Cross-format tests the per-format round-trip suites cannot cover on their
// own: import in one format, export in another, and confirm the model
// survives the trip. Per-format suites (`ABCRoundTripTests`,
// `GuidoRoundTripTests`, `MusicXMLRoundTripTests`, `MIDIRoundTripTests`,
// `JohnnySonicRoundTripTests`) already exercise each exporter/importer pair
// in isolation; this file chains two of those pairs together instead.
struct CrossFormatRoundTripTests {
}

// MARK: -

extension CrossFormatRoundTripTests {
    @Test
    func crossFormat_abcToMusicXML_preservesNotes() throws {
        var table = NoteTable<BeatTime, Pitch>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: "C4")
        table.insert(attack: BeatTime(1), duration: BeatDuration(2), pitch: "E4")
        table.insert(attack: BeatTime(3), duration: BeatDuration(1), pitch: "G4")

        let part = Part(name: "Piano", noteTable: table)
        let work = Work(name: "CrossFormat", content: .standardBeat([part], TempoMap()))

        let viaABC = try roundTrip(work,
                                   exporter: ABC.Exporter(),
                                   importer: ABC.Importer(),
                                   fileFormat: .abc)
        let abcPart = try namedStandardPart(viaABC, "Piano")
        let intermediate = Work(name: "CrossFormat", content: .standardBeat([abcPart], TempoMap()))

        let viaMusicXML = try roundTrip(intermediate,
                                        exporter: MusicXML.Exporter(),
                                        importer: MusicXML.Importer(),
                                        fileFormat: .musicXML)
        let musicXMLPart = try #require(standardBeatParts(of: viaMusicXML)?.first)

        expectNoteTablesMatch(musicXMLPart.noteTable, table)
    }

    @Test
    func crossFormat_fixedBarring_consistentAcrossABCGuidoAndMusicXML() throws {
        // A note starting mid-measure and crossing one bar boundary. All
        // three formats express this as tied segments on the shared 4/4
        // grid; each importer recombines the ties on the way back in, so
        // the recovered note tables should agree with each other as well
        // as with the original.
        var table = NoteTable<BeatTime, Pitch>()

        table.insert(attack: BeatTime(3), duration: BeatDuration(4), pitch: "C4")
        table.insert(attack: BeatTime(7), duration: BeatDuration(1), pitch: "E4")

        let part = Part(name: "Piano", noteTable: table)
        let work = Work(name: "Barring", content: .standardBeat([part], TempoMap()))

        let viaABC = try roundTrip(work,
                                   exporter: ABC.Exporter(),
                                   importer: ABC.Importer(),
                                   fileFormat: .abc)
        let abcPart = try namedStandardPart(viaABC, "Piano")

        let viaGuido = try roundTrip(work,
                                     exporter: Guido.Exporter(),
                                     importer: Guido.Importer(),
                                     fileFormat: .gmn)
        let guidoPart = try #require(standardBeatParts(of: viaGuido)?.first)

        let viaMusicXML = try roundTrip(work,
                                        exporter: MusicXML.Exporter(),
                                        importer: MusicXML.Importer(),
                                        fileFormat: .musicXML)
        let musicXMLPart = try #require(standardBeatParts(of: viaMusicXML)?.first)

        expectNoteTablesMatch(abcPart.noteTable, table)
        expectNoteTablesMatch(guidoPart.noteTable, table)
        expectNoteTablesMatch(musicXMLPart.noteTable, table)
    }

    @Test
    func crossFormat_guidoToABC_preservesNotes() throws {
        var table = NoteTable<BeatTime, Pitch>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: "C4")
        table.insert(attack: BeatTime(1), duration: BeatDuration(1), pitch: "D4")
        table.insert(attack: BeatTime(2), duration: BeatDuration(2), pitch: "F4")

        let part = Part(name: "Piano", noteTable: table)
        let work = Work(name: "CrossFormat", content: .standardBeat([part], TempoMap()))

        let viaGuido = try roundTrip(work,
                                     exporter: Guido.Exporter(),
                                     importer: Guido.Importer(),
                                     fileFormat: .gmn)
        let guidoPart = try #require(standardBeatParts(of: viaGuido)?.first)
        let intermediate = Work(name: "CrossFormat", content: .standardBeat([guidoPart], TempoMap()))

        let viaABC = try roundTrip(intermediate,
                                   exporter: ABC.Exporter(),
                                   importer: ABC.Importer(),
                                   fileFormat: .abc)
        let abcPart = try namedStandardPart(viaABC, "Piano")

        expectNoteTablesMatch(abcPart.noteTable, table)
    }

    @Test
    func crossFormat_musicXMLToMIDI_preservesNotes() throws {
        var table = NoteTable<BeatTime, Pitch>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: "C4")
        table.insert(attack: BeatTime(1), duration: BeatDuration(1), pitch: "E4")
        table.insert(attack: BeatTime(2), duration: BeatDuration(2), pitch: "G4")

        let part = Part(name: "Piano", noteTable: table)
        let work = Work(name: "CrossFormat", content: .standardBeat([part], TempoMap()))

        let viaMusicXML = try roundTrip(work,
                                        exporter: MusicXML.Exporter(),
                                        importer: MusicXML.Importer(),
                                        fileFormat: .musicXML)
        let musicXMLPart = try #require(standardBeatParts(of: viaMusicXML)?.first)

        // MIDI's exporter only accepts `.keyboardBeat` content (pitches as
        // `NoteNumber`), unlike ABC/Guido/MusicXML's `.standardBeat`
        // (pitches as `Pitch`) — this is the one leg of the sweep-up that
        // crosses a pitch-notation boundary, not just a format boundary, so
        // the intermediate part is rebuilt note-by-note via `noteNumber(for:)`.
        let midiTable = try asNoteNumbers(musicXMLPart.noteTable)
        let expectedTable = try asNoteNumbers(table)

        let intermediate = Work(name: "CrossFormat", content: .keyboardBeat([Part(name: "Piano", noteTable: midiTable)], TempoMap()))

        let viaMIDI = try roundTrip(intermediate,
                                    exporter: MIDI.Exporter(),
                                    importer: MIDI.Importer(),
                                    fileFormat: .midi)
        let midiPart = try #require(keyboardBeatParts(of: viaMIDI)?.first)

        expectNoteTablesMatch(midiPart.noteTable, expectedTable)
    }
}
