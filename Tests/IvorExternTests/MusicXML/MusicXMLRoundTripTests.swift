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
    func roundTrip_articulationAndSlur_preservesFlags() throws {
        var table = NoteTable<BeatTime, Pitch>()

        table.insert(attack: BeatTime(0),
                     duration: BeatDuration(1),
                     pitch: "C4",
                     extras: Extras(elements: [Extra(name: Extra.accent.name, values: []),
                                               Extra(name: Extra.slurStart.name, values: [.string("1")])]))
        table.insert(attack: BeatTime(1),
                     duration: BeatDuration(1),
                     pitch: "D4",
                     extras: Extras(elements: [Extra(name: Extra.slurEnd.name, values: [.string("1")])]))

        let part = Part(name: "Piano", noteTable: table)
        let work = Work(name: "Articulation", content: .standardBeat([part], TempoMap()))

        let recovered = try roundTrip(work,
                                      exporter: MusicXML.Exporter(),
                                      importer: MusicXML.Importer(),
                                      fileFormat: .musicXML)
        let recoveredPart = try #require(standardBeatParts(of: recovered)?.first)

        var flags: [(accent: Bool, slurStart: String?, slurEnd: String?)] = []

        recoveredPart.noteTable.forEach { _, _, _, _, _, extras in
            flags.append((hasFlag(extras, .accent), stringValue(extras, .slurStart), stringValue(extras, .slurEnd)))
        }

        #expect(flags.count == 2)
        #expect(flags[0].accent)
        #expect(flags[0].slurStart == "1")
        #expect(flags[1].slurEnd == "1")
    }

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

    // Elevation is the vertical angle of pan, so it rides on the `PanMap`
    // even though MusicXML declares it inside `<midi-instrument>` — and it
    // survives the trip on a part with no instrument assignment of its own.
    @Test
    func roundTrip_panMap_preservesVertical() throws {
        var table = NoteTable<BeatTime, Pitch>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: "C4")

        var panMap = PanMap<BeatTime>()

        panMap.insert(time: BeatTime(0), pan: Pan(vertical: 45))

        let part = Part(name: "Piano", noteTable: table, panMap: panMap)
        let work = Work(name: "Elevation", content: .standardBeat([part], TempoMap()))

        let recovered = try roundTrip(work,
                                      exporter: MusicXML.Exporter(),
                                      importer: MusicXML.Importer(),
                                      fileFormat: .musicXML)
        let recoveredPart = try #require(standardBeatParts(of: recovered)?.first)

        #expect(recoveredPart.panMap[.zero] == Pan(vertical: 45))
    }

    // MusicXML declares elevation once per part, so it applies to every
    // pan change in that part, not just the first.
    @Test
    func roundTrip_panMap_appliesVerticalToEveryEntry() throws {
        var table = NoteTable<BeatTime, Pitch>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(8), pitch: "C4")

        var panMap = PanMap<BeatTime>()

        panMap.insert(time: BeatTime(0), pan: Pan(horizontal: -90, vertical: 30))
        panMap.insert(time: BeatTime(4), pan: Pan(horizontal: 90, vertical: 30))

        let part = Part(name: "Piano", noteTable: table, panMap: panMap)
        let work = Work(name: "Elevation", content: .standardBeat([part], TempoMap()))

        let recovered = try roundTrip(work,
                                      exporter: MusicXML.Exporter(),
                                      importer: MusicXML.Importer(),
                                      fileFormat: .musicXML)
        let recoveredPart = try #require(standardBeatParts(of: recovered)?.first)
        var verticals: [Pan.Angle] = []

        recoveredPart.panMap.forEach { _, _, pan, _ in verticals.append(pan.vertical) }

        #expect(!verticals.isEmpty)
        #expect(verticals.allSatisfy { $0 == 30 })
        #expect(recoveredPart.panMap[BeatTime(4)] == Pan(horizontal: 90, vertical: 30))
    }

    @Test
    func roundTrip_midiInstrumentExtras_preservesExactValues() throws {
        var table = NoteTable<BeatTime, Pitch>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: "C4")

        var instrumentMap = InstrumentMap<BeatTime>()

        try instrumentMap.insert(time: BeatTime(0),
                                 instrument: #require(Instrument(stringValue: "Acoustic Grand Piano")),
                                 extras: Extras(elements: [Extra(name: Extra.midiProgram.name, values: [.int(1)]),
                                                           Extra(name: Extra.midiVolume.name, values: [.double(80)]),
                                                           Extra(name: Extra.midiUnpitched.name, values: [.int(38)])]))

        let part = Part(name: "Piano", noteTable: table, instrumentMap: instrumentMap)
        let work = Work(name: "InstrumentExtras", content: .standardBeat([part], TempoMap()))

        let recovered = try roundTrip(work,
                                      exporter: MusicXML.Exporter(),
                                      importer: MusicXML.Importer(),
                                      fileFormat: .musicXML)
        let recoveredPart = try #require(standardBeatParts(of: recovered)?.first)

        var program: Int?
        var volume: Double?
        var unpitched: Int?

        recoveredPart.instrumentMap.forEach { _, _, _, extras in
            program = intValue(extras, .midiProgram)
            volume = doubleValue(extras, .midiVolume)
            unpitched = intValue(extras, .midiUnpitched)
        }

        #expect(program == 1)
        #expect(volume == 80)
        #expect(unpitched == 38)
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
    func roundTrip_panMap_preservesHorizontalBeyondHardRight() throws {
        var table = NoteTable<BeatTime, Pitch>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: "C4")

        var panMap = PanMap<BeatTime>()

        panMap.insert(time: BeatTime(0), pan: Pan(horizontal: 135))

        let part = Part(name: "Piano", noteTable: table, panMap: panMap)
        let work = Work(name: "PanDegree", content: .standardBeat([part], TempoMap()))

        let recovered = try roundTrip(work,
                                      exporter: MusicXML.Exporter(),
                                      importer: MusicXML.Importer(),
                                      fileFormat: .musicXML)
        let recoveredPart = try #require(standardBeatParts(of: recovered)?.first)

        #expect(recoveredPart.panMap[.zero] == Pan(horizontal: 135))
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
