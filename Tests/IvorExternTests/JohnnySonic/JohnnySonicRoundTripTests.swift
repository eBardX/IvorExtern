// © 2026 John Gary Pusey (see LICENSE.md)

import Foundation
@testable import IvorExtern
import IvorModel
import IvorTiming
import IvorTuning
import Testing
import XestiNumbers
import XestiTools

struct JohnnySonicRoundTripTests {
}

// MARK: -

extension JohnnySonicRoundTripTests {
    @Test
    func roundTrip_absoluteBeatNotes_preservesAttackDurationAndPitch() throws {
        var table = NoteTable<BeatTime, Frequency>()

        try table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: #require(Frequency(numberValue: Number(220.0))))
        try table.insert(attack: BeatTime(1), duration: BeatDuration(1), pitch: #require(Frequency(numberValue: Number(440.0))))

        let part = Part(name: "Tone", noteTable: table)
        let work = Work(name: "Notes", content: .absoluteBeat([part], TempoMap()))

        let recovered = try roundTrip(work,
                                      exporter: JohnnySonic.Exporter(),
                                      importer: JohnnySonic.Importer(),
                                      fileFormat: .dkm)
        let recoveredPart = try #require(absoluteBeatParts(of: recovered)?.first)

        expectNoteTablesMatch(recoveredPart.noteTable, table)
    }

    @Test
    func roundTrip_dynamics_preservesEntries() throws {
        var table = NoteTable<BeatTime, NoteNumber>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: NoteNumber(60))

        var dynamicMap = DynamicMap<BeatTime>()

        try dynamicMap.insert(time: BeatTime(0), dynamic: #require(Dynamic(numberValue: Number(0.5))))

        let part = Part(name: "Piano", noteTable: table, dynamicMap: dynamicMap)
        let work = Work(name: "Dynamics", content: .keyboardBeat([part], TempoMap()))

        let recovered = try roundTrip(work,
                                      exporter: JohnnySonic.Exporter(),
                                      importer: JohnnySonic.Importer(),
                                      fileFormat: .dkm)
        let recoveredPart = try #require(keyboardBeatParts(of: recovered)?.first)

        expectDynamicMapsMatch(recoveredPart.dynamicMap, dynamicMap)
    }

    @Test
    func roundTrip_instrumentChanges_splitNotesIntoSeparateParts() throws {
        var table = NoteTable<BeatTime, NoteNumber>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: NoteNumber(60))
        table.insert(attack: BeatTime(1), duration: BeatDuration(1), pitch: NoteNumber(64))

        var instrumentMap = InstrumentMap<BeatTime>()

        try instrumentMap.insert(time: BeatTime(0), instrument: #require(Instrument(stringValue: "Piano")))
        try instrumentMap.insert(time: BeatTime(1), instrument: #require(Instrument(stringValue: "Flute")))

        let part = Part(name: "Lead", noteTable: table, instrumentMap: instrumentMap)
        let work = Work(name: "Instruments", content: .keyboardBeat([part], TempoMap()))

        let recovered = try roundTrip(work,
                                      exporter: JohnnySonic.Exporter(),
                                      importer: JohnnySonic.Importer(),
                                      fileFormat: .dkm)
        let recoveredParts = try #require(keyboardBeatParts(of: recovered))

        // Every `/Pitches` line carries its own instrument name, and the
        // importer groups notes into parts *by instrument*
        // (`_pitchesNotes(byInstrumentIn:)`), not by the originating
        // `Part`. So a single part whose instrument changes mid-stream
        // round-trips as two parts, one per instrument — a genuine format
        // asymmetry, not a defect. Document it here rather than asserting
        // a same-part-layout round trip the format cannot provide.
        try #require(recoveredParts.count == 2)

        let pianoPart = try #require(recoveredParts.first { $0.name == "Piano" })
        let flutePart = try #require(recoveredParts.first { $0.name == "Flute" })

        #expect(pianoPart.noteTable.timeRange != nil)
        #expect(flutePart.noteTable.timeRange != nil)
    }

    @Test
    func roundTrip_keyboardBeatNotes_preservesAttackDurationAndPitch() throws {
        var table = NoteTable<BeatTime, NoteNumber>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: NoteNumber(60))
        table.insert(attack: BeatTime(1), duration: BeatDuration(2), pitch: NoteNumber(64))
        table.insert(attack: BeatTime(3), duration: BeatDuration(1), pitch: NoteNumber(67))

        let part = Part(name: "Piano", noteTable: table)
        let work = Work(name: "Notes", content: .keyboardBeat([part], TempoMap()))

        let recovered = try roundTrip(work,
                                      exporter: JohnnySonic.Exporter(),
                                      importer: JohnnySonic.Importer(),
                                      fileFormat: .dkm)
        let recoveredPart = try #require(keyboardBeatParts(of: recovered)?.first)

        expectNoteTablesMatch(recoveredPart.noteTable, table)
    }

    @Test
    func roundTrip_multiPart_withDistinctInstruments_preservesEachPartsNotes() throws {
        var table1 = NoteTable<BeatTime, NoteNumber>()

        table1.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: NoteNumber(60))

        var instrumentMap1 = InstrumentMap<BeatTime>()

        try instrumentMap1.insert(time: BeatTime(0), instrument: #require(Instrument(stringValue: "Piano")))

        var table2 = NoteTable<BeatTime, NoteNumber>()

        table2.insert(attack: BeatTime(0), duration: BeatDuration(2), pitch: NoteNumber(67))

        var instrumentMap2 = InstrumentMap<BeatTime>()

        try instrumentMap2.insert(time: BeatTime(0), instrument: #require(Instrument(stringValue: "Flute")))

        // Distinct instruments are load-bearing here: the importer groups
        // notes into parts by instrument (see
        // `roundTrip_instrumentChanges_splitNotesIntoSeparateParts`), so two
        // parts sharing the default instrument would collapse into one on
        // the way back in.
        let parts = [Part(name: "P1", noteTable: table1, instrumentMap: instrumentMap1),
                     Part(name: "P2", noteTable: table2, instrumentMap: instrumentMap2)]
        let work = Work(name: "MultiPart", content: .keyboardBeat(parts, TempoMap()))

        let recovered = try roundTrip(work,
                                      exporter: JohnnySonic.Exporter(),
                                      importer: JohnnySonic.Importer(),
                                      fileFormat: .dkm)
        let recoveredParts = try #require(keyboardBeatParts(of: recovered))

        try #require(recoveredParts.count == 2)

        let pianoPart = try #require(recoveredParts.first { $0.name == "Piano" })
        let flutePart = try #require(recoveredParts.first { $0.name == "Flute" })

        expectNoteTablesMatch(pianoPart.noteTable, table1)
        expectNoteTablesMatch(flutePart.noteTable, table2)
    }

    @Test
    func roundTrip_pan_preservesEntries() throws {
        var table = NoteTable<BeatTime, NoteNumber>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: NoteNumber(60))

        var panMap = PanMap<BeatTime>()

        try panMap.insert(time: BeatTime(0), pan: #require(Pan(numberValue: Number(-0.5))))

        let part = Part(name: "Piano", noteTable: table, panMap: panMap)
        let work = Work(name: "Pan", content: .keyboardBeat([part], TempoMap()))

        let recovered = try roundTrip(work,
                                      exporter: JohnnySonic.Exporter(),
                                      importer: JohnnySonic.Importer(),
                                      fileFormat: .dkm)
        let recoveredPart = try #require(keyboardBeatParts(of: recovered)?.first)

        expectPanMapsMatch(recoveredPart.panMap, panMap)
    }

    @Test
    func roundTrip_tempo_preservesFlatValue() throws {
        var tempoMap = TempoMap()

        tempoMap.insert(beatTime: BeatTime(0), tempo: Tempo(120))

        var table = NoteTable<BeatTime, NoteNumber>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: NoteNumber(60))

        let part = Part(name: "Piano", noteTable: table)
        let work = Work(name: "Tempo", content: .keyboardBeat([part], tempoMap))

        let recovered = try roundTrip(work,
                                      exporter: JohnnySonic.Exporter(),
                                      importer: JohnnySonic.Importer(),
                                      fileFormat: .dkm)
        let recoveredTempoMap = try #require(recovered.tempoMap)

        // A ramp between two distinct tempos is intentionally not asserted
        // here: `DKMTempoLine` interpolates continuously between whole
        // beats, and the importer resamples that curve at its own
        // resolution rather than reproducing the exporter's exact anchor
        // points, so a flat tempo (start == end) is the one shape every
        // JohnnySonic round trip can be held to exactly.
        #expect(recoveredTempoMap[BeatTime(0)] == Tempo(120))
        #expect(recoveredTempoMap[BeatTime(1)] == Tempo(120))
    }
}
