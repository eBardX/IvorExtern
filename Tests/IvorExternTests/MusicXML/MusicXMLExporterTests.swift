// © 2025–2026 John Gary Pusey (see LICENSE.md)

import Foundation
@testable import IvorExtern
import IvorModel
import IvorMusicXML
import IvorTiming
import IvorTuning
import Testing
import XestiNumbers
import XestiTools

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
    func convert_instrumentMap_recognizedName_emitsMidiProgram() throws {
        var table = NoteTable<BeatTime, Pitch>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: "C4")

        var instrumentMap = InstrumentMap<BeatTime>()

        try instrumentMap.insert(time: BeatTime(0), instrument: #require(Instrument(stringValue: "Acoustic Grand Piano")))

        let part = Part(name: "Piano", noteTable: table, instrumentMap: instrumentMap)
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
    func convert_instrumentMap_unrecognizedName_omitsMidiProgram() throws {
        var table = NoteTable<BeatTime, Pitch>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: "C4")

        var instrumentMap = InstrumentMap<BeatTime>()

        try instrumentMap.insert(time: BeatTime(0), instrument: #require(Instrument(stringValue: "Kazoo Ensemble")))

        let part = Part(name: "", noteTable: table, instrumentMap: instrumentMap)
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
    func write_multipleWorks_throwsMultipleWorksNotSupported() {
        let works = [standardBeatWork(parts: []), standardBeatWork(parts: [])]

        #expect(throws: MusicXML.Error.self) {
            try MusicXML.Exporter().write(works: works, as: .musicXML)
        }
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
