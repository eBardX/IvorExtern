// © 2026 John Gary Pusey (see LICENSE.md)

import Foundation
import IvorABC
@testable import IvorExtern
import IvorModel
import IvorTiming
import IvorTuning
import Testing
import XestiNumbers
import XestiTools

struct ABCExporterTests {
}

// MARK: -

extension ABCExporterTests {
    @Test
    func convert_chordGrouping_differingDurationsStaySeparate() throws {
        var table = NoteTable<BeatTime, Pitch>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: "C4")
        table.insert(attack: BeatTime(0), duration: BeatDuration(2), pitch: "E4")

        let work = standardBeatWork(parts: [Part(name: "", noteTable: table)])
        let tune = try ABC.Exporter().convert(work)
        let symbols = symbols(in: tune)

        #expect(!symbols.contains { if case .chord = $0 { true } else { false } })
        #expect(symbols.filter { if case .note = $0 { true } else { false } }.count == 2)
    }

    @Test
    func convert_chordGrouping_sameStartAndDurationGroupIntoChord() throws {
        var table = NoteTable<BeatTime, Pitch>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: "C4")
        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: "E4")

        let work = standardBeatWork(parts: [Part(name: "", noteTable: table)])
        let tune = try ABC.Exporter().convert(work)
        let symbols = symbols(in: tune)
        let chord = try #require(symbols.compactMap { symbol -> ABCChord? in
            guard case let .chord(chord) = symbol
            else { return nil }

            return chord
        }.first)

        #expect(chord.notes.count == 2)
    }

    @Test
    func convert_coincidentDynamicPair_emitsMark() throws {
        var table = NoteTable<BeatTime, Pitch>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: "C4")

        var dynamicMap = DynamicMap<BeatTime>()

        try dynamicMap.insert(time: BeatTime(0), dynamic: #require(Dynamic(numberValue: Number(0.5))))
        try dynamicMap.insert(time: BeatTime(0), dynamic: #require(Dynamic(numberValue: Number(0.8))))

        let part = Part(name: "", noteTable: table, dynamicMap: dynamicMap)
        let tune = try ABC.Exporter().convert(standardBeatWork(parts: [part]))
        let decorations = decorations(in: tune)

        #expect(decorations.contains { $0.name.stringValue == "ff" })
        #expect(!decorations.contains { $0.name.stringValue.hasPrefix("crescendo") })
    }

    @Test
    func convert_distinctTimeDynamicPair_emitsHairpin() throws {
        var table = NoteTable<BeatTime, Pitch>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(3), pitch: "C4")
        table.insert(attack: BeatTime(3), duration: BeatDuration(1), pitch: "D4")

        var dynamicMap = DynamicMap<BeatTime>()

        try dynamicMap.insert(time: BeatTime(0), dynamic: #require(Dynamic(numberValue: Number(0.3))))
        try dynamicMap.insert(time: BeatTime(3), dynamic: #require(Dynamic(numberValue: Number(0.8))))

        let part = Part(name: "", noteTable: table, dynamicMap: dynamicMap)
        let tune = try ABC.Exporter().convert(standardBeatWork(parts: [part]))
        let decorations = decorations(in: tune)

        #expect(decorations.contains { $0.name.stringValue == "crescendo(" })
        #expect(decorations.contains { $0.name.stringValue == "crescendo)" })
    }

    @Test
    func convert_emptyWork_producesHeaderOnlyTune() throws {
        let work = standardBeatWork(parts: [])
        let tune = try ABC.Exporter().convert(work)

        #expect(!tune.header.isEmpty)
        #expect(symbols(in: tune).isEmpty)
    }

    @Test
    func convert_glissandoNote_exportsAtStartPitch() throws {
        var table = NoteTable<BeatTime, Pitch>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), startPitch: "C4", endPitch: "G4")

        let work = standardBeatWork(parts: [Part(name: "", noteTable: table)])
        let tune = try ABC.Exporter().convert(work)
        let note = try #require(symbols(in: tune).compactMap { symbol -> ABCNote? in
            guard case let .note(note) = symbol
            else { return nil }

            return note
        }.first)

        #expect(note.pitch.letter == .c)
    }

    @Test
    func convert_instrumentMap_recognizedName_emitsMidiDirective() throws {
        var table = NoteTable<BeatTime, Pitch>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: "C4")

        var instrumentMap = InstrumentMap<BeatTime>()

        try instrumentMap.insert(time: BeatTime(0), instrument: #require(Instrument(stringValue: "Acoustic Grand Piano")))

        let part = Part(name: "", noteTable: table, instrumentMap: instrumentMap)
        let tune = try ABC.Exporter().convert(standardBeatWork(parts: [part]))
        let directive = try #require(tune.body.compactMap { entry -> ABCDirective? in
            guard case let .directive(directive) = entry
            else { return nil }

            return directive
        }.first)

        #expect(directive.name.stringValue.lowercased() == "midi")
        #expect(directive.value == "program 0")
    }

    @Test
    func convert_instrumentMap_unrecognizedName_omitsDirective() throws {
        var table = NoteTable<BeatTime, Pitch>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: "C4")

        var instrumentMap = InstrumentMap<BeatTime>()

        try instrumentMap.insert(time: BeatTime(0), instrument: #require(Instrument(stringValue: "Kazoo Ensemble")))

        let part = Part(name: "", noteTable: table, instrumentMap: instrumentMap)
        let tune = try ABC.Exporter().convert(standardBeatWork(parts: [part]))

        #expect(!tune.body.contains { if case .directive = $0 { true } else { false } })
    }

    @Test
    func convert_multiPart_emitsOneVoicePerPart() throws {
        var table1 = NoteTable<BeatTime, Pitch>()

        table1.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: "C4")

        var table2 = NoteTable<BeatTime, Pitch>()

        table2.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: "G4")

        let parts = [Part(name: "Lead", noteTable: table1), Part(name: "Bass", noteTable: table2)]
        let tune = try ABC.Exporter().convert(standardBeatWork(parts: parts))
        let voiceIDs = tune.header.compactMap { entry -> ABCVoice.ID? in
            guard case let .field(.voice(voice)) = entry
            else { return nil }

            return voice.id
        }

        #expect(Set(voiceIDs).count == 2)
    }

    @Test
    func convert_singlePartNamed_stillEmitsVoiceField() throws {
        var table = NoteTable<BeatTime, Pitch>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: "C4")

        let work = standardBeatWork(parts: [Part(name: "Piano", noteTable: table)])
        let tune = try ABC.Exporter().convert(work)
        let bodyHasVoiceField = tune.body.contains { if case .field(.voice) = $0 { true } else { false } }
        let headerHasVoiceField = tune.header.contains { if case .field(.voice) = $0 { true } else { false } }

        #expect(bodyHasVoiceField)
        #expect(headerHasVoiceField)
    }

    @Test
    func convert_singlePartUnnamed_omitsVoiceField() throws {
        var table = NoteTable<BeatTime, Pitch>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: "C4")

        let work = standardBeatWork(parts: [Part(name: "", noteTable: table)])
        let tune = try ABC.Exporter().convert(work)
        let bodyHasVoiceField = tune.body.contains { if case .field(.voice) = $0 { true } else { false } }
        let headerHasVoiceField = tune.header.contains { if case .field(.voice) = $0 { true } else { false } }

        #expect(!bodyHasVoiceField)
        #expect(!headerHasVoiceField)
    }

    @Test
    func convert_noteCrossingBarline_splitsIntoTiedSegments() throws {
        var table = NoteTable<BeatTime, Pitch>()

        table.insert(attack: BeatTime(3), duration: BeatDuration(2), pitch: "C4")

        let work = standardBeatWork(parts: [Part(name: "", noteTable: table)])
        let tune = try ABC.Exporter().convert(work)
        let notes = symbols(in: tune).compactMap { symbol -> ABCNote? in
            guard case let .note(note) = symbol
            else { return nil }

            return note
        }

        #expect(notes.count == 2)
        #expect(notes[0].tie == .regular)
        #expect(notes[1].tie == nil)
    }

    @Test
    func convert_shortFinalMeasure_isRestFilled() throws {
        var table = NoteTable<BeatTime, Pitch>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: "C4")

        let work = standardBeatWork(parts: [Part(name: "", noteTable: table)])
        let tune = try ABC.Exporter().convert(work)
        let symbols = symbols(in: tune)

        #expect(symbols.contains { if case .rest = $0 { true } else { false } })
    }

    @Test
    func convert_singleNote_emitsNoteSymbol() throws {
        var table = NoteTable<BeatTime, Pitch>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: "C4")

        let work = standardBeatWork(parts: [Part(name: "", noteTable: table)])
        let tune = try ABC.Exporter().convert(work)
        let note = try #require(symbols(in: tune).compactMap { symbol -> ABCNote? in
            guard case let .note(note) = symbol
            else { return nil }

            return note
        }.first)

        #expect(note.pitch.letter == .c)
        #expect(note.pitch.accidental == .natural)
        #expect(note.pitch.octave.uintValue == 4)
    }

    @Test
    func convert_tempoMap_emitsTempoField() throws {
        var tempoMap = TempoMap()

        tempoMap.insert(beatTime: BeatTime(0), tempo: Tempo(144))

        let work = Work(name: "Test", content: .standardBeat([], tempoMap))
        let tune = try ABC.Exporter().convert(work)
        let tempo = try #require(tune.header.compactMap { entry -> ABCTempo? in
            guard case let .field(.tempo(tempo)) = entry
            else { return nil }

            return tempo
        }.first)

        #expect(tempo.rate == 144)
    }

    @Test
    func convert_tripletDuration_emitsTupletSymbol() throws {
        var table = NoteTable<BeatTime, Pitch>()

        let third = Number(numerator: 1, denominator: 3)

        table.insert(attack: BeatTime(0), duration: BeatDuration(third), pitch: "C4")
        table.insert(attack: BeatTime(third), duration: BeatDuration(third), pitch: "D4")
        table.insert(attack: BeatTime(Number(numerator: 2, denominator: 3)), duration: BeatDuration(third), pitch: "E4")

        let work = standardBeatWork(parts: [Part(name: "", noteTable: table)])
        let tune = try ABC.Exporter().convert(work)
        let tuplets = symbols(in: tune).compactMap { symbol -> ABCTuplet? in
            guard case let .tuplet(tuplet) = symbol
            else { return nil }

            return tuplet
        }

        #expect(tuplets.count == 3)
        #expect(tuplets.allSatisfy { $0.noteCount == 3 })
    }

    @Test
    func convert_unrepresentableDuration_throws() {
        var table = NoteTable<BeatTime, Pitch>()

        // An 11th-note has no legal ABC spelling: its reduced denominator's
        // odd factor (11) exceeds the tuplet noteCount cap of 9.
        table.insert(attack: BeatTime(0), duration: BeatDuration(Number(numerator: 1, denominator: 11)), pitch: "C4")

        let work = standardBeatWork(parts: [Part(name: "", noteTable: table)])

        #expect(throws: ABC.Error.self) {
            try ABC.Exporter().convert(work)
        }
    }

    @Test
    func convert_wallTimeContent_throwsUnsupportedTimeBasis() {
        let work = Work(name: "Test", content: .standardWall([]))

        #expect(throws: ABC.Error.self) {
            try ABC.Exporter().convert(work)
        }
    }

    @Test
    func convert_wrongPitchNotation_throwsUnsupportedPitchNotation() {
        let work = Work(name: "Test", content: .keyboardBeat([], TempoMap()))

        #expect(throws: ABC.Error.self) {
            try ABC.Exporter().convert(work)
        }
    }

    @Test
    func writableFileFormats_containsABC() {
        #expect(ABC.Exporter().writableFileFormats == [.abc])
    }

    @Test
    func write_emptyWorks_throwsNoWorksToExport() {
        #expect(throws: ABC.Error.self) {
            try ABC.Exporter().write(works: [], as: .abc)
        }
    }

    @Test
    func write_multipleWorks_succeeds() throws {
        let works = [standardBeatWork(parts: []), standardBeatWork(parts: [])]
        let file = try ABC.Exporter().write(works: works, as: .abc)

        #expect(file.regularFileContents != nil)
    }

    @Test
    func write_singleWork_succeeds() throws {
        var table = NoteTable<BeatTime, Pitch>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: "C4")

        let work = standardBeatWork(parts: [Part(name: "", noteTable: table)])
        let file = try ABC.Exporter().write(works: [work], as: .abc)

        #expect(file.regularFileContents != nil)
    }

    @Test
    func write_unsupportedFormat_throws() {
        #expect(throws: ABC.Error.self) {
            try ABC.Exporter().write(works: [standardBeatWork(parts: [])], as: .midi)
        }
    }
}
