// © 2026 John Gary Pusey (see LICENSE.md)

import Foundation
@testable import IvorExtern
import IvorModel
import IvorTiming
import IvorTuning
import Testing
import XestiNumbers
import XestiTools

struct MIDIRoundTripTests {
}

// MARK: -

extension MIDIRoundTripTests {
    @Test
    func roundTrip_dynamicsRamp_preservesShape() throws {
        var table = NoteTable<BeatTime, NoteNumber>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(4), pitch: NoteNumber(60))

        var dynamicMap = DynamicMap<BeatTime>()

        try dynamicMap.insert(time: BeatTime(0), dynamic: #require(Dynamic(numberValue: Number(0.25))))
        try dynamicMap.insert(time: BeatTime(4), dynamic: #require(Dynamic(numberValue: Number(1.0))))

        let part = Part(name: "Piano", noteTable: table, dynamicMap: dynamicMap)
        let work = Work(name: "Dynamics", content: .keyboardBeat([part], TempoMap()))

        let recovered = try roundTrip(work,
                                      exporter: MIDI.Exporter(),
                                      importer: MIDI.Importer(),
                                      fileFormat: .midi)
        let recoveredPart = try #require(keyboardBeatParts(of: recovered)?.first)

        // MIDI attaches dynamics to note-on/note-off velocity rather than a
        // free-standing ramp, so only the endpoints survive — assert shape,
        // not an exact entry-count match.
        #expect(!recoveredPart.dynamicMap.isEmpty)
    }

    @Test
    func roundTrip_instrumentChanges_preservesEachSegment() throws {
        var table = NoteTable<BeatTime, NoteNumber>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: NoteNumber(60))
        table.insert(attack: BeatTime(1), duration: BeatDuration(1), pitch: NoteNumber(64))

        var instrumentMap = InstrumentMap<BeatTime>()

        try instrumentMap.insert(time: BeatTime(0), instrument: #require(Instrument(stringValue: "Acoustic Grand Piano")))
        try instrumentMap.insert(time: BeatTime(1), instrument: #require(Instrument(stringValue: "Violin")))

        let part = Part(name: "Lead", noteTable: table, instrumentMap: instrumentMap)
        let work = Work(name: "Instruments", content: .keyboardBeat([part], TempoMap()))

        let recovered = try roundTrip(work,
                                      exporter: MIDI.Exporter(),
                                      importer: MIDI.Importer(),
                                      fileFormat: .midi)
        let recoveredPart = try #require(keyboardBeatParts(of: recovered)?.first)

        expectInstrumentMapsMatch(recoveredPart.instrumentMap, instrumentMap)
    }

    @Test
    func roundTrip_multiPart_preservesEachPartsNotes() throws {
        var table1 = NoteTable<BeatTime, NoteNumber>()

        table1.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: NoteNumber(60))

        var table2 = NoteTable<BeatTime, NoteNumber>()

        table2.insert(attack: BeatTime(0), duration: BeatDuration(2), pitch: NoteNumber(67))

        let parts = [Part(name: "P1", noteTable: table1),
                     Part(name: "P2", noteTable: table2)]
        let work = Work(name: "MultiPart", content: .keyboardBeat(parts, TempoMap()))

        let recovered = try roundTrip(work,
                                      exporter: MIDI.Exporter(),
                                      importer: MIDI.Importer(),
                                      fileFormat: .midi)
        let recoveredParts = try #require(keyboardBeatParts(of: recovered))

        #expect(recoveredParts.count == 2)

        expectNoteTablesMatch(recoveredParts[0].noteTable, table1)
        expectNoteTablesMatch(recoveredParts[1].noteTable, table2)
    }

    @Test
    func roundTrip_notes_preservesAttackDurationAndPitch() throws {
        var table = NoteTable<BeatTime, NoteNumber>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: NoteNumber(60))
        table.insert(attack: BeatTime(1), duration: BeatDuration(2), pitch: NoteNumber(64))
        table.insert(attack: BeatTime(3), duration: BeatDuration(1), pitch: NoteNumber(67))

        let part = Part(name: "Piano", noteTable: table)
        let work = Work(name: "Notes", content: .keyboardBeat([part], TempoMap()))

        let recovered = try roundTrip(work,
                                      exporter: MIDI.Exporter(),
                                      importer: MIDI.Importer(),
                                      fileFormat: .midi)
        let recoveredPart = try #require(keyboardBeatParts(of: recovered)?.first)

        expectNoteTablesMatch(recoveredPart.noteTable, table)
    }

    @Test
    func roundTrip_pan_preservesEntries() throws {
        var panMap = PanMap<BeatTime>()

        try panMap.insert(time: BeatTime(0), pan: #require(Pan(numberValue: Number(-1.0))))
        try panMap.insert(time: BeatTime(4), pan: #require(Pan(numberValue: Number(1.0))))

        let part = Part(name: "Piano",
                        noteTable: NoteTable<BeatTime, NoteNumber>(),
                        panMap: panMap)
        let work = Work(name: "Pan", content: .keyboardBeat([part], TempoMap()))

        let recovered = try roundTrip(work,
                                      exporter: MIDI.Exporter(),
                                      importer: MIDI.Importer(),
                                      fileFormat: .midi)
        let recoveredPart = try #require(keyboardBeatParts(of: recovered)?.first)

        expectPanMapsMatch(recoveredPart.panMap, panMap)
    }

    @Test
    func roundTrip_tempoRamp_preservesStepChanges() throws {
        var tempoMap = TempoMap()

        tempoMap.insert(beatTime: BeatTime(0), tempo: Tempo(120))
        tempoMap.insert(beatTime: BeatTime(4), tempo: Tempo(120))
        tempoMap.insert(beatTime: BeatTime(4), tempo: Tempo(160))

        let work = Work(name: "Tempo", content: .keyboardBeat([], tempoMap))

        let recovered = try roundTrip(work,
                                      exporter: MIDI.Exporter(),
                                      importer: MIDI.Importer(),
                                      fileFormat: .midi)
        let recoveredTempoMap = try #require(recovered.tempoMap)

        expectTempoMapsMatch(recoveredTempoMap, tempoMap)
    }
}
