// © 2025–2026 John Gary Pusey (see LICENSE.md)

import Foundation
@testable import IvorExtern
import IvorModel
import IvorMXL
import IvorTiming
import IvorTuning
import Testing
import XestiNumbers
import XestiTools

// swiftlint:disable file_length

struct MusicXMLExporterTests {
}

// MARK: -

extension MusicXMLExporterTests {
    @Test
    func convert_chordGrouping_differingDurationsStaySeparate() throws {
        var table = NoteTable<BeatTime, Pitch>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: "C4")
        table.insert(attack: BeatTime(0), duration: BeatDuration(2), pitch: "E4")

        let work = standardBeatWork(parts: [Part(name: "", noteTable: table)])
        let score = try MusicXML.Exporter().convert(work)
        let notes = pitchedNotes(in: score)

        #expect(notes.count == 2)
        #expect(notes.allSatisfy { !isChord($0) })
    }

    @Test
    func convert_chordGrouping_sameStartAndDurationGroupIntoChord() throws {
        var table = NoteTable<BeatTime, Pitch>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: "C4")
        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: "E4")

        let work = standardBeatWork(parts: [Part(name: "", noteTable: table)])
        let score = try MusicXML.Exporter().convert(work)
        let notes = pitchedNotes(in: score)

        #expect(notes.count == 2)
        #expect(!isChord(notes[0]))
        #expect(isChord(notes[1]))
    }

    @Test
    func convert_coincidentDynamicPair_emitsMark() throws {
        var table = NoteTable<BeatTime, Pitch>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: "C4")

        var dynamicMap = DynamicMap<BeatTime>()

        dynamicMap.insert(time: BeatTime(0), dynamic: .p)
        dynamicMap.insert(time: BeatTime(0), dynamic: .ff)

        let part = Part(name: "", noteTable: table, dynamicMap: dynamicMap)
        let score = try MusicXML.Exporter().convert(standardBeatWork(parts: [part]))
        let marks = dynamicsItems(in: score)

        #expect(marks.contains(.ff))
        #expect(wedges(in: score).isEmpty)
    }

    @Test
    func convert_distinctTimeDynamicPair_emitsWedge() throws {
        var table = NoteTable<BeatTime, Pitch>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(3), pitch: "C4")
        table.insert(attack: BeatTime(3), duration: BeatDuration(1), pitch: "D4")

        var dynamicMap = DynamicMap<BeatTime>()

        dynamicMap.insert(time: BeatTime(0), dynamic: .p)
        dynamicMap.insert(time: BeatTime(3), dynamic: .f)

        let part = Part(name: "", noteTable: table, dynamicMap: dynamicMap)
        let score = try MusicXML.Exporter().convert(standardBeatWork(parts: [part]))
        let wedges = wedges(in: score)

        #expect(wedges.contains { $0.kind == .crescendo })
        #expect(wedges.contains { $0.kind == .stop })

        // Both endpoints are also written as explicit `<dynamics>` marks,
        // since a wedge alone carries no target level.
        let marks = dynamicsItems(in: score)

        #expect(marks.contains(.p))
        #expect(marks.contains(.f))
    }

    @Test
    func convert_dynamicMarkExtra_emitsFixedCaseItem() throws {
        var table = NoteTable<BeatTime, Pitch>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: "C4")

        var dynamicMap = DynamicMap<BeatTime>()

        dynamicMap.insert(time: BeatTime(0),
                          dynamic: .mp,
                          extras: Extras(elements: [Extra(name: Extra.dynamicMark.name, values: [.string("sfz")])]))

        let part = Part(name: "", noteTable: table, dynamicMap: dynamicMap)
        let score = try MusicXML.Exporter().convert(standardBeatWork(parts: [part]))
        let marks = dynamicsItems(in: score)

        #expect(marks.contains(.sfz))
    }

    @Test
    func convert_dynamicMarkExtra_freeText_emitsOtherDynamics() throws {
        var table = NoteTable<BeatTime, Pitch>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: "C4")

        var dynamicMap = DynamicMap<BeatTime>()

        dynamicMap.insert(time: BeatTime(0),
                          dynamic: .mp,
                          extras: Extras(elements: [Extra(name: Extra.dynamicMark.name, values: [.string("poco f")])]))

        let part = Part(name: "", noteTable: table, dynamicMap: dynamicMap)
        let score = try MusicXML.Exporter().convert(standardBeatWork(parts: [part]))
        let marks = dynamicsItems(in: score)

        #expect(marks.contains(.otherDynamics(MXLOtherText(value: "poco f"))))
    }

    @Test
    func convert_emptyWork_producesNoParts() throws {
        let work = standardBeatWork(parts: [])
        let score = try MusicXML.Exporter().convert(work)

        #expect(score.parts.isEmpty)
    }

    @Test
    func convert_firstMeasure_carriesDivisionsAttributes() throws {
        var table = NoteTable<BeatTime, Pitch>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: "C4")

        let work = standardBeatWork(parts: [Part(name: "", noteTable: table)])
        let score = try MusicXML.Exporter().convert(work)
        let firstMeasure = try #require(score.parts.first?.measures.first)
        let attributes = firstMeasure.items.compactMap { item -> MXLAttributes? in
            guard case let .attributes(attributes) = item
            else { return nil }

            return attributes
        }

        #expect(attributes.count == 1)
        #expect(attributes.first?.divisions != nil)
    }

    @Test
    func convert_glissandoNote_exportsAtStartPitch() throws {
        var table = NoteTable<BeatTime, Pitch>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), startPitch: "C4", endPitch: "G4")

        let work = standardBeatWork(parts: [Part(name: "", noteTable: table)])
        let score = try MusicXML.Exporter().convert(work)
        let pitch = try #require(notes(in: score).compactMap(pitch).first)

        #expect(pitch.step == .c)
    }

    @Test
    func convert_instrumentTable_midiChannelAndBankExtras_emitMidiChannelAndBank() throws {
        var table = NoteTable<BeatTime, Pitch>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: "C4")

        var instrumentTable = InstrumentTable<BeatTime>()

        try instrumentTable.insert(time: BeatTime(0),
                                   instrument: #require(Instrument(stringValue: "Acoustic Grand Piano")),
                                   extras: Extras(elements: [Extra(name: Extra.midiBank.name, values: [.int(130)])]))

        let part = Part(name: "Piano", noteTable: table, instrumentTable: instrumentTable, extras: channelExtras(3))
        let score = try MusicXML.Exporter().convert(standardBeatWork(parts: [part]))
        let scorePart = try #require(score.partList.items.compactMap { item -> MusicXML.ScorePart? in
            guard case let .scorePart(scorePart) = item
            else { return nil }

            return scorePart
        }.first)

        #expect(scorePart.group2.first?.midiInstrument?.midiChannel?.uintValue == 3)
        // `<midi-bank>` numbers from 1.
        #expect(scorePart.group2.first?.midiInstrument?.midiBank?.uintValue == 131)
    }

    @Test
    func convert_instrumentTable_recognizedName_emitsMidiProgram() throws {
        var table = NoteTable<BeatTime, Pitch>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: "C4")

        var instrumentTable = InstrumentTable<BeatTime>()

        try instrumentTable.insert(time: BeatTime(0), instrument: #require(Instrument(stringValue: "Acoustic Grand Piano")))

        let part = Part(name: "Piano", noteTable: table, instrumentTable: instrumentTable)
        let score = try MusicXML.Exporter().convert(standardBeatWork(parts: [part]))
        let scorePart = try #require(score.partList.items.compactMap { item -> MusicXML.ScorePart? in
            guard case let .scorePart(scorePart) = item
            else { return nil }

            return scorePart
        }.first)

        #expect(scorePart.instrument.first?.name == "Acoustic Grand Piano")
        #expect(scorePart.group2.first?.midiInstrument?.midiProgram?.uintValue == 1)
    }

    @Test
    func convert_instrumentTable_recognizedPercussionName_emitsMidiUnpitched() throws {
        var table = NoteTable<BeatTime, Pitch>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: "C4")

        var instrumentTable = InstrumentTable<BeatTime>()

        try instrumentTable.insert(time: BeatTime(0), instrument: #require(Instrument(stringValue: "Acoustic Snare")))

        let part = Part(name: "Drums", noteTable: table, instrumentTable: instrumentTable)
        let score = try MusicXML.Exporter().convert(standardBeatWork(parts: [part]))
        let scorePart = try #require(score.partList.items.compactMap { item -> MusicXML.ScorePart? in
            guard case let .scorePart(scorePart) = item
            else { return nil }

            return scorePart
        }.first)

        #expect(scorePart.instrument.first?.name == "Acoustic Snare")
        #expect(scorePart.group2.first?.midiInstrument?.midiUnpitched?.uintValue == 39)
        #expect(scorePart.group2.first?.midiInstrument?.midiProgram == nil)
    }

    @Test
    func convert_instrumentTable_unrecognizedName_omitsMidiProgram() throws {
        var table = NoteTable<BeatTime, Pitch>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: "C4")

        var instrumentTable = InstrumentTable<BeatTime>()

        try instrumentTable.insert(time: BeatTime(0), instrument: #require(Instrument(stringValue: "Kazoo Ensemble")))

        let part = Part(name: "", noteTable: table, instrumentTable: instrumentTable)
        let score = try MusicXML.Exporter().convert(standardBeatWork(parts: [part]))
        let scorePart = try #require(score.partList.items.compactMap { item -> MusicXML.ScorePart? in
            guard case let .scorePart(scorePart) = item
            else { return nil }

            return scorePart
        }.first)

        #expect(scorePart.instrument.first?.name == "Kazoo Ensemble")
        #expect(scorePart.group2.isEmpty)
    }

    @Test
    func convert_midiChannelExtraWithoutInstrumentTable_emitsMidiInstrumentWithoutProgram() throws {
        var table = NoteTable<BeatTime, Pitch>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: "C4")

        let part = Part(name: "", noteTable: table, extras: channelExtras(5))
        let score = try MusicXML.Exporter().convert(standardBeatWork(parts: [part]))
        let scorePart = try #require(score.partList.items.compactMap { item -> MusicXML.ScorePart? in
            guard case let .scorePart(scorePart) = item
            else { return nil }

            return scorePart
        }.first)

        #expect(scorePart.group2.first?.midiInstrument?.midiChannel?.uintValue == 5)
        #expect(scorePart.group2.first?.midiInstrument?.midiProgram == nil)
    }

    @Test
    func convert_multiPart_emitsOnePartPerPart() throws {
        var table1 = NoteTable<BeatTime, Pitch>()

        table1.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: "C4")

        var table2 = NoteTable<BeatTime, Pitch>()

        table2.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: "G4")

        let parts = [Part(name: "Lead", noteTable: table1), Part(name: "Bass", noteTable: table2)]
        let score = try MusicXML.Exporter().convert(standardBeatWork(parts: parts))
        let names = score.partList.items.compactMap { item -> String? in
            guard case let .scorePart(scorePart) = item
            else { return nil }

            return scorePart.name.value
        }

        #expect(score.parts.count == 2)
        #expect(names == ["Lead", "Bass"])
    }

    @Test
    func convert_negativeMidiExtras_writeNoneOfThem() throws {
        var table = NoteTable<BeatTime, Pitch>()

        table.insert(attack: .zero, duration: BeatDuration(1), pitch: "C4")

        var instrumentTable = InstrumentTable<BeatTime>()

        try instrumentTable.insert(time: .zero,
                                   instrument: #require(Instrument(stringValue: "Acoustic Grand Piano")),
                                   extras: Extras(elements: [Extra(name: Extra.midiProgram.name, values: [.int(-1)]),
                                                             Extra(name: Extra.midiUnpitched.name, values: [.int(-1)])]))

        let part = Part(name: "Piano", noteTable: table, instrumentTable: instrumentTable, extras: channelExtras(-1))
        let score = try MusicXML.Exporter().convert(standardBeatWork(parts: [part]))
        let scorePart = try #require(score.partList.items.compactMap { item -> MusicXML.ScorePart? in
            guard case let .scorePart(scorePart) = item
            else { return nil }

            return scorePart
        }.first)

        #expect(scorePart.group2.isEmpty)
    }

    @Test
    func convert_noteCrossingBarline_splitsIntoTiedSegments() throws {
        var table = NoteTable<BeatTime, Pitch>()

        table.insert(attack: BeatTime(3), duration: BeatDuration(2), pitch: "C4")

        let work = standardBeatWork(parts: [Part(name: "", noteTable: table)])
        let score = try MusicXML.Exporter().convert(work)
        let notes = pitchedNotes(in: score)
        let ties = notes.flatMap(ties)

        #expect(notes.count == 2)
        #expect(notes.allSatisfy { pitch($0)?.step == .c })
        #expect(ties.contains(.start))
        #expect(ties.contains(.stop))
    }

    @Test
    func convert_panMap_emitsSoundPan() throws {
        var table = NoteTable<BeatTime, Pitch>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: "C4")

        var panMap = PanMap<BeatTime>()

        panMap.insert(time: BeatTime(0), pan: .right)

        let part = Part(name: "", noteTable: table, panMap: panMap)
        let score = try MusicXML.Exporter().convert(standardBeatWork(parts: [part]))
        let sound = try #require(sounds(in: score).first { $0.pan != nil })

        #expect(sound.pan == 90)
    }

    @Test
    func convert_panStep_emitsOnlyTheNewPan() throws {
        var table = NoteTable<BeatTime, Pitch>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: "C4")
        table.insert(attack: BeatTime(4), duration: BeatDuration(1), pitch: "D4")

        var panMap = PanMap<BeatTime>()

        panMap.insert(time: BeatTime(0), pan: .left)
        panMap.insert(time: BeatTime(4), pan: .left)
        panMap.insert(time: BeatTime(4), pan: .right)

        let part = Part(name: "", noteTable: table, panMap: panMap)
        let score = try MusicXML.Exporter().convert(standardBeatWork(parts: [part]))

        #expect(sounds(in: score).compactMap(\.pan) == [-90, 90])
    }

    @Test
    func convert_releaseVelocityExtra_emitsEndDynamicsOnLastSegmentOnly() throws {
        var table = NoteTable<BeatTime, Pitch>()

        table.insert(attack: BeatTime(3),
                     duration: BeatDuration(2),
                     pitch: "C4",
                     extras: Extras(elements: [Extra(name: Extra.releaseVelocity.name, values: [.int(40)])]))

        let work = standardBeatWork(parts: [Part(name: "", noteTable: table)])
        let score = try MusicXML.Exporter().convert(work)
        let notes = pitchedNotes(in: score)

        // 40 / 90 = 44.444…%, rounded to two decimal places.
        #expect(notes.map(\.endDynamics) == [nil, 44.44])
        #expect(notes.allSatisfy { $0.dynamics == nil })
    }

    @Test
    func convert_shortFinalMeasure_isRestFilled() throws {
        var table = NoteTable<BeatTime, Pitch>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: "C4")

        let work = standardBeatWork(parts: [Part(name: "", noteTable: table)])
        let score = try MusicXML.Exporter().convert(work)

        #expect(notes(in: score).contains { note -> Bool in
            guard case let .regularNote(fullNote, _, _) = note.content,
                  case .rest = fullNote.content
            else { return false }

            return true
        })
    }

    @Test
    func convert_singleNote_emitsNoteSymbol() throws {
        var table = NoteTable<BeatTime, Pitch>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: "C4")

        let work = standardBeatWork(parts: [Part(name: "", noteTable: table)])
        let score = try MusicXML.Exporter().convert(work)
        let pitch = try #require(notes(in: score).compactMap(pitch).first)

        #expect(pitch.step == .c)
        #expect(pitch.alter == nil)
        #expect(pitch.octave.uintValue == 4)
    }

    @Test
    func convert_tempoMap_emitsTempoDirection() throws {
        var tempoMap = TempoMap()

        tempoMap.insert(beatTime: BeatTime(0), tempo: Tempo(144))

        // MusicXML has no header separate from its parts — a `<sound tempo>`
        // has to live inside a `<direction>` inside a part, so at least one
        // part (even an empty one) is required for the tempo to have
        // anywhere to attach.
        let work = Work(name: "Test", content: .standardBeat([Part(name: "", noteTable: NoteTable())], tempoMap))
        let score = try MusicXML.Exporter().convert(work)
        let tempo = try #require(sounds(in: score).compactMap(\.tempo).first)

        #expect(tempo == 144)
    }

    @Test
    func convert_wallTimeContent_throwsUnsupportedTimeBasis() {
        let work = Work(name: "Test", content: .standardWall([]))

        #expect(throws: MusicXML.Error.self) {
            try MusicXML.Exporter().convert(work)
        }
    }

    @Test
    func convert_wrongPitchNotation_throwsUnsupportedPitchNotation() {
        let work = Work(name: "Test", content: .keyboardBeat([], TempoMap()))

        #expect(throws: MusicXML.Error.self) {
            try MusicXML.Exporter().convert(work)
        }
    }

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

        for note in recoveredPart.noteTable {
            flags.append((hasFlag(note.extras, .accent), stringValue(note.extras, .slurStart), stringValue(note.extras, .slurEnd)))
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
    func roundTrip_info_preservesWork() throws {
        let work = sampleMusicXMLWork()
        let recovered = try roundTrip(work,
                                      exporter: MusicXML.Exporter(),
                                      importer: MusicXML.Importer(),
                                      fileFormat: .musicXML)
        let recoveredPart = try namedStandardPart(recovered, "Flute")
        let entry = try #require(recoveredPart.instrumentTable.first)
        var expected = work.info

        // `movement number` and `work number` come back first, since they
        // have elements of their own ahead of `<identification>`.
        expected.remarks = expected.remarks.filter { $0.label == "work number" } + expected.remarks.filter { $0.label != "work number" }

        // IvorMXL collapses the whitespace in an element's text, line
        // breaks included.
        expected.rights = [RightsNotice(text: "© 1998 Acme Line two", scope: .music)].compactMap(\.self)

        #expect(recovered.info == expected)
        #expect(stringValue(entry.extras, .instrumentName) == "Flauto 1")
        #expect(stringValue(entry.extras, .instrumentAbbreviation) == "Fl. 1")
    }

    @Test
    func roundTrip_instrumentTable_preservesRecognizedName() throws {
        var table = NoteTable<BeatTime, Pitch>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: "C4")

        var instrumentTable = InstrumentTable<BeatTime>()

        try instrumentTable.insert(time: BeatTime(0), instrument: #require(Instrument(stringValue: "Acoustic Grand Piano")))

        let part = Part(name: "Piano", noteTable: table, instrumentTable: instrumentTable)
        let work = Work(name: "Instrument", content: .standardBeat([part], TempoMap()))

        let recovered = try roundTrip(work,
                                      exporter: MusicXML.Exporter(),
                                      importer: MusicXML.Importer(),
                                      fileFormat: .musicXML)
        let recoveredPart = try #require(standardBeatParts(of: recovered)?.first)

        var instruments: [Instrument] = []

        for entry in recoveredPart.instrumentTable {
            instruments.append(entry.instrument)
        }

        #expect(instruments.contains { $0.stringValue == "Acoustic Grand Piano" })
    }

    @Test
    func roundTrip_midiInstrumentExtras_preservesExactValues() throws {
        var table = NoteTable<BeatTime, Pitch>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: "C4")

        var instrumentTable = InstrumentTable<BeatTime>()

        try instrumentTable.insert(time: BeatTime(0),
                                   instrument: #require(Instrument(stringValue: "Acoustic Grand Piano")),
                                   extras: Extras(elements: [Extra(name: Extra.midiProgram.name, values: [.int(1)]),
                                                             Extra(name: Extra.midiVolume.name, values: [.double(80)]),
                                                             Extra(name: Extra.midiUnpitched.name, values: [.int(38)])]))

        let part = Part(name: "Piano", noteTable: table, instrumentTable: instrumentTable)
        let work = Work(name: "InstrumentExtras", content: .standardBeat([part], TempoMap()))

        let recovered = try roundTrip(work,
                                      exporter: MusicXML.Exporter(),
                                      importer: MusicXML.Importer(),
                                      fileFormat: .musicXML)
        let recoveredPart = try #require(standardBeatParts(of: recovered)?.first)

        var program: Int?
        var volume: Double?
        var unpitched: Int?

        for entry in recoveredPart.instrumentTable {
            program = intValue(entry.extras, .midiProgram)
            volume = doubleValue(entry.extras, .midiVolume)
            unpitched = intValue(entry.extras, .midiUnpitched)
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

        for entry in recoveredPart.panMap {
            verticals.append(entry.pan.vertical)
        }

        #expect(!verticals.isEmpty)
        #expect(verticals.allSatisfy { $0 == 30 })
        #expect(recoveredPart.panMap[BeatTime(4)] == Pan(horizontal: 90, vertical: 30))
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

    @Test(arguments: [nil, 1, 40, 64, 127])
    func roundTrip_releaseVelocity_preservesValue(_ velocity: Int?) throws {
        var table = NoteTable<BeatTime, Pitch>()

        table.insert(attack: BeatTime(0),
                     duration: BeatDuration(1),
                     pitch: "C4",
                     extras: velocity.map { Extras(elements: [Extra(name: Extra.releaseVelocity.name, values: [.int($0)])]) })

        let part = Part(name: "Piano", noteTable: table)
        let work = Work(name: "ReleaseVelocity", content: .standardBeat([part], TempoMap()))

        let recovered = try roundTrip(work,
                                      exporter: MusicXML.Exporter(),
                                      importer: MusicXML.Importer(),
                                      fileFormat: .musicXML)
        let recoveredPart = try #require(standardBeatParts(of: recovered)?.first)

        var recoveredVelocities: [Int?] = []

        for note in recoveredPart.noteTable {
            recoveredVelocities.append(intValue(note.extras, .releaseVelocity))
        }

        #expect(recoveredVelocities == [velocity])
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

    @Test
    func writableFileFormats_containsMusicXMLAndMXL() {
        #expect(MusicXML.Exporter().writableFileFormats == [.musicXML, .mxl])
    }

    @Test
    func write_emptyWorks_throwsNoWorksToExport() {
        #expect(throws: MusicXML.Error.self) {
            try MusicXML.Exporter().write(works: [], as: .musicXML)
        }
    }

    @Test
    func write_info_writesWorkIdentificationAndCredits() throws {
        let score = try MusicXML.Exporter().convert(sampleMusicXMLWork())
        let identification = try #require(score.identification)

        #expect(score.work?.title == "Collected Pieces")
        #expect(score.work?.number == "Op. 2")
        #expect(score.movementTitle == "Aubade")
        #expect(identification.creator == [MXLTypedText(value: "J. Smith", kind: "composer"),
                                           MXLTypedText(value: "A. Poet", kind: "lyricist")])
        #expect(identification.rights == [MXLTypedText(value: "© 1998 Acme\nLine two", kind: "music")])
        #expect(identification.encoding?.items == [.encoder(MXLTypedText(value: "T. Scribe"))])
        #expect(identification.source == "From a fiddler")
        #expect(identification.miscellaneous?.field == [MXLMiscellaneous.Field(value: "Morning Piece", name: "alternate title"),
                                                        MXLMiscellaneous.Field(value: "A plain remark", name: "remark")])
        #expect(score.credit.map(\.kind) == [["title"], ["subtitle"], ["dedication"]])
    }

    @Test
    func write_multipleWorks_throwsMultipleWorksNotSupported() {
        let works = [standardBeatWork(parts: []), standardBeatWork(parts: [])]

        #expect(throws: MusicXML.Error.self) {
            try MusicXML.Exporter().write(works: works, as: .musicXML)
        }
    }

    @Test
    func write_noTitle_writesWorkNameAsWorkTitle() throws {
        let score = try MusicXML.Exporter().convert(Work(name: "Sketch 3", content: .standardBeat([], TempoMap())))

        #expect(score.work?.title == "Sketch 3")
        #expect(score.movementTitle == nil)
        #expect(score.identification == nil)
        #expect(score.credit.isEmpty)
    }

    @Test
    func write_singleWork_musicXML_succeeds() throws {
        var table = NoteTable<BeatTime, Pitch>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: "C4")

        let work = standardBeatWork(parts: [Part(name: "", noteTable: table)])
        let file = try MusicXML.Exporter().write(works: [work], as: .musicXML)

        #expect(file.regularFileContents != nil)
    }

    @Test
    func write_singleWork_mxl_succeeds() throws {
        var table = NoteTable<BeatTime, Pitch>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: "C4")

        let work = standardBeatWork(parts: [Part(name: "", noteTable: table)])
        let file = try MusicXML.Exporter().write(works: [work], as: .mxl)

        #expect(file.regularFileContents != nil)
    }

    @Test
    func write_unsupportedFormat_throws() {
        #expect(throws: MusicXML.Error.self) {
            try MusicXML.Exporter().write(works: [standardBeatWork(parts: [])], as: .midi)
        }
    }
}

// swiftlint:enable file_length
