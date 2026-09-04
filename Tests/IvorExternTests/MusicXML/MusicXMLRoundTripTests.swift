// © 2026 John Gary Pusey (see LICENSE.md)

import Foundation
@testable import IvorExtern
import IvorModel
import IvorTiming
import IvorTuning
import Testing
import XestiNumbers
import XestiTools

struct MusicXMLRoundTripTests {
}

// MARK: -

extension MusicXMLRoundTripTests {
    @Test
    func roundTrip_chord_preservesSimultaneousNotes() throws {
        var table = NoteTable<BeatTime, Pitch>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: "C4")
        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: "E4")
        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: "G4")

        let part = Part(name: "Piano", noteTable: table)
        let work = Work(name: "Chord", content: .standardBeat([part], TempoMap()))

        let recovered = try roundTrip(work,
                                      exporter: MusicXML.Exporter(),
                                      importer: MusicXML.Importer(),
                                      fileFormat: .musicXML)
        let recoveredPart = try #require(standardBeatParts(of: recovered)?.first)

        expectNoteTablesMatch(recoveredPart.noteTable, table)
    }

    @Test
    func roundTrip_compressed_preservesNotes() throws {
        var table = NoteTable<BeatTime, Pitch>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: "C4")

        let part = Part(name: "Piano", noteTable: table)
        let work = Work(name: "Compressed", content: .standardBeat([part], TempoMap()))

        let recovered = try roundTrip(work,
                                      exporter: MusicXML.Exporter(),
                                      importer: MusicXML.Importer(),
                                      fileFormat: .mxl)
        let recoveredPart = try #require(standardBeatParts(of: recovered)?.first)

        expectNoteTablesMatch(recoveredPart.noteTable, table)
    }

    @Test
    func roundTrip_instrumentMap_preservesRecognizedName() throws {
        var table = NoteTable<BeatTime, Pitch>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: "C4")

        var instrumentMap = InstrumentMap<BeatTime>()

        try instrumentMap.insert(time: BeatTime(0), instrument: #require(Instrument(stringValue: "Acoustic Grand Piano")))

        let part = Part(name: "Piano", noteTable: table, instrumentMap: instrumentMap)
        let work = Work(name: "Instrument", content: .standardBeat([part], TempoMap()))

        let recovered = try roundTrip(work,
                                      exporter: MusicXML.Exporter(),
                                      importer: MusicXML.Importer(),
                                      fileFormat: .musicXML)
        let recoveredPart = try #require(standardBeatParts(of: recovered)?.first)

        var instruments: [Instrument] = []

        recoveredPart.instrumentMap.forEach { _, _, instrument, _ in instruments.append(instrument) }

        #expect(instruments.contains { $0.stringValue == "Acoustic Grand Piano" })
    }

    @Test
    func roundTrip_multiPart_preservesEachPartsNotesAndNames() throws {
        var table1 = NoteTable<BeatTime, Pitch>()

        table1.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: "C4")

        var table2 = NoteTable<BeatTime, Pitch>()

        table2.insert(attack: BeatTime(0), duration: BeatDuration(2), pitch: "G3")

        let parts = [Part(name: "Lead", noteTable: table1), Part(name: "Bass", noteTable: table2)]
        let work = Work(name: "MultiPart", content: .standardBeat(parts, TempoMap()))

        let recovered = try roundTrip(work,
                                      exporter: MusicXML.Exporter(),
                                      importer: MusicXML.Importer(),
                                      fileFormat: .musicXML)
        let recoveredParts = try #require(standardBeatParts(of: recovered))

        #expect(recoveredParts.count == 2)

        let lead = try #require(recoveredParts.first { $0.name == "Lead" })
        let bass = try #require(recoveredParts.first { $0.name == "Bass" })

        expectNoteTablesMatch(lead.noteTable, table1)
        expectNoteTablesMatch(bass.noteTable, table2)
    }

    @Test
    func roundTrip_noteCrossingBarline_preservesTotalDuration() throws {
        var table = NoteTable<BeatTime, Pitch>()

        table.insert(attack: BeatTime(3), duration: BeatDuration(2), pitch: "C4")

        let part = Part(name: "Piano", noteTable: table)
        let work = Work(name: "Tie", content: .standardBeat([part], TempoMap()))

        let recovered = try roundTrip(work,
                                      exporter: MusicXML.Exporter(),
                                      importer: MusicXML.Importer(),
                                      fileFormat: .musicXML)
        let recoveredPart = try #require(standardBeatParts(of: recovered)?.first)

        // The tied halves recombine on import into a single note spanning
        // the original attack and duration — barring is a synthesized
        // export-side detail, not part of the model.
        expectNoteTablesMatch(recoveredPart.noteTable, table)
    }

    @Test
    func roundTrip_notes_preservesAttackDurationAndPitch() throws {
        var table = NoteTable<BeatTime, Pitch>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: "C4")
        table.insert(attack: BeatTime(1), duration: BeatDuration(2), pitch: "E4")
        table.insert(attack: BeatTime(3), duration: BeatDuration(1), pitch: "G4")

        let part = Part(name: "Piano", noteTable: table)
        let work = Work(name: "Notes", content: .standardBeat([part], TempoMap()))

        let recovered = try roundTrip(work,
                                      exporter: MusicXML.Exporter(),
                                      importer: MusicXML.Importer(),
                                      fileFormat: .musicXML)
        let recoveredPart = try #require(standardBeatParts(of: recovered)?.first)

        expectNoteTablesMatch(recoveredPart.noteTable, table)
    }

    @Test
    func roundTrip_panMap_preservesHardRight() throws {
        var table = NoteTable<BeatTime, Pitch>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: "C4")

        var panMap = PanMap<BeatTime>()

        panMap.insert(time: BeatTime(0), pan: .right)

        let part = Part(name: "Piano", noteTable: table, panMap: panMap)
        let work = Work(name: "Pan", content: .standardBeat([part], TempoMap()))

        let recovered = try roundTrip(work,
                                      exporter: MusicXML.Exporter(),
                                      importer: MusicXML.Importer(),
                                      fileFormat: .musicXML)
        let recoveredPart = try #require(standardBeatParts(of: recovered)?.first)

        #expect(recoveredPart.panMap[BeatTime(0)] == .right)
    }

    @Test
    func roundTrip_tempo_preservesFlatValue() throws {
        var tempoMap = TempoMap()

        tempoMap.insert(beatTime: BeatTime(0), tempo: Tempo(96))

        var table = NoteTable<BeatTime, Pitch>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: "C4")

        let part = Part(name: "Piano", noteTable: table)
        let work = Work(name: "Tempo", content: .standardBeat([part], tempoMap))

        let recovered = try roundTrip(work,
                                      exporter: MusicXML.Exporter(),
                                      importer: MusicXML.Importer(),
                                      fileFormat: .musicXML)
        let recoveredTempoMap = try #require(recovered.tempoMap)

        #expect(recoveredTempoMap[BeatTime(0)] == Tempo(96))
    }

    // A duration whose fraction of a whole note has no power-of-2
    // denominator has no plain ABC spelling, but MusicXML's integer
    // `<divisions>` represents any rational exactly — no tuplet
    // reconstruction is needed.
    @Test
    func roundTrip_tripletNotes_preservesDurations() throws {
        var table = NoteTable<BeatTime, Pitch>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(Number(numerator: 1, denominator: 3)), pitch: "C4")
        table.insert(attack: BeatTime(Number(numerator: 1, denominator: 3)),
                     duration: BeatDuration(Number(numerator: 1, denominator: 3)),
                     pitch: "D4")
        table.insert(attack: BeatTime(Number(numerator: 2, denominator: 3)),
                     duration: BeatDuration(Number(numerator: 1, denominator: 3)),
                     pitch: "E4")

        let part = Part(name: "Piano", noteTable: table)
        let work = Work(name: "Triplet", content: .standardBeat([part], TempoMap()))

        let recovered = try roundTrip(work,
                                      exporter: MusicXML.Exporter(),
                                      importer: MusicXML.Importer(),
                                      fileFormat: .musicXML)
        let recoveredPart = try #require(standardBeatParts(of: recovered)?.first)

        expectNoteTablesMatch(recoveredPart.noteTable, table)
    }
}
