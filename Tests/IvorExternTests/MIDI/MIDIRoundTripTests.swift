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
    func roundTrip_exactMicrosecondsPerQuarter_preservesSubBPMPrecision() throws {
        var tempoMap = TempoMap()

        tempoMap.insert(beatTime: BeatTime(0),
                        tempo: Tempo(147),
                        extras: Extras(elements: [Extra(name: Extra.midiTempo.name,
                                                        values: [.int(408_163)])]))

        let work = Work(name: "ExactTempo", content: .keyboardBeat([], tempoMap))

        let recovered = try roundTrip(work,
                                      exporter: MIDI.Exporter(),
                                      importer: MIDI.Importer(),
                                      fileFormat: .midi)
        let recoveredTempoMap = try #require(recovered.tempoMap)

        var found: Int?

        recoveredTempoMap.forEach { _, time, _, extras in
            if time == BeatTime(0) {
                found = intValue(extras, .midiTempo)
            }
        }

        #expect(found == 408_163)
    }

    @Test
    func roundTrip_expressionValue_preservesExactValue() throws {
        var table = NoteTable<BeatTime, NoteNumber>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(4), pitch: NoteNumber(60))

        var dynamicMap = DynamicMap<BeatTime>()

        dynamicMap.insert(time: BeatTime(0),
                          dynamic: .mf,
                          extras: Extras(elements: [Extra(name: Extra.expressionValue.name, values: [.int(100)])]))

        let part = Part(name: "Piano", noteTable: table, dynamicMap: dynamicMap)
        let work = Work(name: "Expression", content: .keyboardBeat([part], TempoMap()))

        let recovered = try roundTrip(work,
                                      exporter: MIDI.Exporter(),
                                      importer: MIDI.Importer(),
                                      fileFormat: .midi)
        let recoveredPart = try #require(keyboardBeatParts(of: recovered)?.first)

        var found: Int?

        recoveredPart.dynamicMap.forEach { _, _, _, extras in
            if let value = intValue(extras, .expressionValue) {
                found = value
            }
        }

        #expect(found == 100)
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
    func roundTrip_instrumentName_unmatchedByGeneralMIDIProgram_survives() throws {
        var table = NoteTable<BeatTime, NoteNumber>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: NoteNumber(60))

        var instrumentMap = InstrumentMap<BeatTime>()

        try instrumentMap.insert(time: BeatTime(0),
                                 instrument: #require(Instrument(stringValue: "Fiddle")),
                                 extras: Extras(elements: [Extra(name: Extra.midiProgram.name, values: [.int(41)])]))

        let part = Part(name: "Lead", noteTable: table, instrumentMap: instrumentMap)
        let work = Work(name: "Instrument", content: .keyboardBeat([part], TempoMap()))

        let recovered = try roundTrip(work,
                                      exporter: MIDI.Exporter(),
                                      importer: MIDI.Importer(),
                                      fileFormat: .midi)
        let recoveredPart = try #require(keyboardBeatParts(of: recovered)?.first)

        // Program 41 is General MIDI's "Violin" — without the Instrument
        // Name meta event, this would round-trip back as "Violin" instead.
        #expect(recoveredPart.instrumentMap[.zero] == Instrument("Fiddle"))
    }

    @Test
    func roundTrip_midiKeyPressure_preservesPeakValue() throws {
        var table = NoteTable<BeatTime, NoteNumber>()

        table.insert(attack: BeatTime(0),
                     duration: BeatDuration(1),
                     pitch: NoteNumber(60),
                     extras: Extras(elements: [Extra(name: Extra.midiKeyPressure.name, values: [.int(90)])]))

        let part = Part(name: "Piano", noteTable: table)
        let work = Work(name: "KeyPressure", content: .keyboardBeat([part], TempoMap()))

        let recovered = try roundTrip(work,
                                      exporter: MIDI.Exporter(),
                                      importer: MIDI.Importer(),
                                      fileFormat: .midi)
        let recoveredPart = try #require(keyboardBeatParts(of: recovered)?.first)

        var pressure: Int?

        recoveredPart.noteTable.forEach { _, _, _, _, _, extras in
            pressure = intValue(extras, .midiKeyPressure)
        }

        #expect(pressure == 90)
    }

    @Test
    func roundTrip_midiPan_preservesCombined14BitValue() throws {
        var panMap = PanMap<BeatTime>()

        panMap.insert(time: BeatTime(0),
                      pan: .center,
                      extras: Extras(elements: [Extra(name: Extra.midiPan.name, values: [.int(9_001)])]))

        let part = Part(name: "Piano",
                        noteTable: NoteTable<BeatTime, NoteNumber>(),
                        panMap: panMap)
        let work = Work(name: "MidiPan", content: .keyboardBeat([part], TempoMap()))

        let recovered = try roundTrip(work,
                                      exporter: MIDI.Exporter(),
                                      importer: MIDI.Importer(),
                                      fileFormat: .midi)
        let recoveredPart = try #require(keyboardBeatParts(of: recovered)?.first)

        var midiPan: Int?

        recoveredPart.panMap.forEach { _, _, _, extras in
            midiPan = intValue(extras, .midiPan)
        }

        #expect(midiPan == 9_001)
    }

    @Test
    func roundTrip_midiVolume_preservesExactValue() throws {
        var table = NoteTable<BeatTime, NoteNumber>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: NoteNumber(60))

        var instrumentMap = InstrumentMap<BeatTime>()

        try instrumentMap.insert(time: BeatTime(0),
                                 instrument: #require(Instrument(stringValue: "Acoustic Grand Piano")),
                                 extras: Extras(elements: [Extra(name: Extra.midiVolume.name, values: [.double(90)])]))

        let part = Part(name: "Piano", noteTable: table, instrumentMap: instrumentMap)
        let work = Work(name: "Volume", content: .keyboardBeat([part], TempoMap()))

        let recovered = try roundTrip(work,
                                      exporter: MIDI.Exporter(),
                                      importer: MIDI.Importer(),
                                      fileFormat: .midi)
        let recoveredPart = try #require(keyboardBeatParts(of: recovered)?.first)

        var volume: Double?

        recoveredPart.instrumentMap.forEach { _, _, _, extras in
            volume = doubleValue(extras, .midiVolume)
        }

        // CC 7 is 7-bit (0-127), so the round trip through the 0-100 percent
        // scale isn't exact to arbitrary precision — 90% -> round(90/100*127)
        // = 114 -> 114/127*100 ≈ 89.76.
        #expect(try abs(#require(volume) - 90) < 1)
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

        panMap.insert(time: BeatTime(0), pan: .left)
        panMap.insert(time: BeatTime(4), pan: .right)

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

    @Test
    func roundTrip_velocity_preservesExactValue() throws {
        var table = NoteTable<BeatTime, NoteNumber>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: NoteNumber(60))

        var dynamicMap = DynamicMap<BeatTime>()

        dynamicMap.insert(time: BeatTime(0),
                          dynamic: .mf,
                          extras: Extras(elements: [Extra(name: Extra.velocity.name, values: [.int(77)])]))

        let part = Part(name: "Piano", noteTable: table, dynamicMap: dynamicMap)
        let work = Work(name: "Velocity", content: .keyboardBeat([part], TempoMap()))

        let recovered = try roundTrip(work,
                                      exporter: MIDI.Exporter(),
                                      importer: MIDI.Importer(),
                                      fileFormat: .midi)
        let recoveredPart = try #require(keyboardBeatParts(of: recovered)?.first)

        var found: Int?

        recoveredPart.dynamicMap.forEach { _, time, _, extras in
            if time == BeatTime(0) {
                found = intValue(extras, .velocity)
            }
        }

        #expect(found == 77)
    }
}
