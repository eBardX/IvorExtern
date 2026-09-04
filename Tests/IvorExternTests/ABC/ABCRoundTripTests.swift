// © 2026 John Gary Pusey (see LICENSE.md)

import Foundation
@testable import IvorExtern
import IvorModel
import IvorTiming
import IvorTuning
import Testing
import XestiNumbers
import XestiTools

// This exporter declares an explicit `V:` for every part except a lone,
// unnamed one (see `ABC.Exporter._needsVoiceFields(parts:)`) and switches
// into it before the first symbol, so a named/multi-part work never lands
// in `ABC.Importer.Walker._routed(_:fileHeader:)`'s implicit "voice 0"
// accumulator — `ABC.Importer._isEmptyImplicitVoice` drops it and every
// part below comes back exactly as written. Tests still look their part up
// by name rather than by index, matching `JohnnySonicRoundTripTests`
// routing around that format's own by-instrument part grouping — not
// working around anything here, just resilient to part order.
struct ABCRoundTripTests {
}

// MARK: -

extension ABCRoundTripTests {
    @Test
    func roundTrip_chord_preservesSimultaneousNotes() throws {
        var table = NoteTable<BeatTime, Pitch>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: "C4")
        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: "E4")
        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: "G4")

        let part = Part(name: "Piano", noteTable: table)
        let work = Work(name: "Chord", content: .standardBeat([part], TempoMap()))

        let recovered = try roundTrip(work,
                                      exporter: ABC.Exporter(),
                                      importer: ABC.Importer(),
                                      fileFormat: .abc)
        let recoveredPart = try namedStandardPart(recovered, "Piano")

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
                                      exporter: ABC.Exporter(),
                                      importer: ABC.Importer(),
                                      fileFormat: .abc)
        let recoveredPart = try namedStandardPart(recovered, "Piano")

        var instruments: [Instrument] = []

        recoveredPart.instrumentMap.forEach { _, _, instrument, _ in instruments.append(instrument) }

        #expect(instruments.first?.stringValue == "Acoustic Grand Piano")
    }

    @Test
    func roundTrip_multiPart_preservesEachPartsNotes() throws {
        var table1 = NoteTable<BeatTime, Pitch>()

        table1.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: "C4")

        var table2 = NoteTable<BeatTime, Pitch>()

        table2.insert(attack: BeatTime(0), duration: BeatDuration(2), pitch: "G3")

        let parts = [Part(name: "Lead", noteTable: table1), Part(name: "Bass", noteTable: table2)]
        let work = Work(name: "MultiPart", content: .standardBeat(parts, TempoMap()))

        let recovered = try roundTrip(work,
                                      exporter: ABC.Exporter(),
                                      importer: ABC.Importer(),
                                      fileFormat: .abc)

        try expectNoteTablesMatch(namedStandardPart(recovered, "Lead").noteTable, table1)
        try expectNoteTablesMatch(namedStandardPart(recovered, "Bass").noteTable, table2)
    }

    @Test
    func roundTrip_noteCrossingBarline_preservesTotalDuration() throws {
        var table = NoteTable<BeatTime, Pitch>()

        table.insert(attack: BeatTime(3), duration: BeatDuration(2), pitch: "C4")

        let part = Part(name: "Piano", noteTable: table)
        let work = Work(name: "Tie", content: .standardBeat([part], TempoMap()))

        let recovered = try roundTrip(work,
                                      exporter: ABC.Exporter(),
                                      importer: ABC.Importer(),
                                      fileFormat: .abc)
        let recoveredPart = try namedStandardPart(recovered, "Piano")

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
                                      exporter: ABC.Exporter(),
                                      importer: ABC.Importer(),
                                      fileFormat: .abc)
        let recoveredPart = try namedStandardPart(recovered, "Piano")

        expectNoteTablesMatch(recoveredPart.noteTable, table)
    }

    @Test
    func roundTrip_singleUnnamedPart_staysUnnamed() throws {
        var table = NoteTable<BeatTime, Pitch>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: "C4")

        let part = Part(name: "", noteTable: table)
        let work = Work(name: "Untitled", content: .standardBeat([part], TempoMap()))

        let recovered = try roundTrip(work,
                                      exporter: ABC.Exporter(),
                                      importer: ABC.Importer(),
                                      fileFormat: .abc)
        let recoveredPart = try namedStandardPart(recovered, "")

        expectNoteTablesMatch(recoveredPart.noteTable, table)
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
                                      exporter: ABC.Exporter(),
                                      importer: ABC.Importer(),
                                      fileFormat: .abc)
        let recoveredTempoMap = try #require(recovered.tempoMap)

        #expect(recoveredTempoMap[BeatTime(0)] == Tempo(96))
    }

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
                                      exporter: ABC.Exporter(),
                                      importer: ABC.Importer(),
                                      fileFormat: .abc)
        let recoveredPart = try namedStandardPart(recovered, "Piano")

        expectNoteTablesMatch(recoveredPart.noteTable, table)
    }
}
