// © 2026 John Gary Pusey (see LICENSE.md)

import Foundation
@testable import IvorExtern
import IvorGuido
import IvorModel
import IvorTiming
import IvorTuning
import Testing
import XestiNumbers
import XestiTools

struct GuidoExporterTests {
}

// MARK: -

extension GuidoExporterTests {
    @Test
    func convert_arbitraryDuration_succeedsWithoutTupletReconstruction() throws {
        var table = NoteTable<BeatTime, Pitch>()

        // Unlike ABC, `GMNDuration` accepts any non-zero rational — an
        // 11th-note has no tuplet marker to reconstruct because it doesn't
        // need one.
        table.insert(attack: BeatTime(0), duration: BeatDuration(Number(numerator: 1, denominator: 11)), pitch: "C4")

        let work = standardBeatWork(parts: [Part(name: "", noteTable: table)])
        let score = try Guido.Exporter().convert(work)
        let notes = symbols(in: score).compactMap { symbol -> GMNNote? in
            guard case let .note(note) = symbol
            else { return nil }

            return note
        }

        #expect(!notes.isEmpty)
    }

    @Test
    func convert_chordGrouping_differingDurationsStaySeparate() throws {
        var table = NoteTable<BeatTime, Pitch>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: "C4")
        table.insert(attack: BeatTime(0), duration: BeatDuration(2), pitch: "E4")

        let work = standardBeatWork(parts: [Part(name: "", noteTable: table)])
        let score = try Guido.Exporter().convert(work)
        let symbols = symbols(in: score)

        #expect(!symbols.contains { if case .chord = $0 { true } else { false } })
        #expect(symbols.filter { if case .note = $0 { true } else { false } }.count == 2)
    }

    @Test
    func convert_chordGrouping_sameStartAndDurationGroupIntoChord() throws {
        var table = NoteTable<BeatTime, Pitch>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: "C4")
        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: "E4")

        let work = standardBeatWork(parts: [Part(name: "", noteTable: table)])
        let score = try Guido.Exporter().convert(work)
        let chord = try #require(symbols(in: score).compactMap { symbol -> GMNChord? in
            guard case let .chord(chord) = symbol
            else { return nil }

            return chord
        }.first)

        #expect(chord.segments.count == 2)
    }

    @Test
    func convert_coincidentDynamicPair_emitsMark() throws {
        var table = NoteTable<BeatTime, Pitch>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: "C4")

        var dynamicMap = DynamicMap<BeatTime>()

        try dynamicMap.insert(time: BeatTime(0), dynamic: #require(Dynamic(numberValue: Number(0.5))))
        try dynamicMap.insert(time: BeatTime(0), dynamic: #require(Dynamic(numberValue: Number(0.8))))

        let part = Part(name: "", noteTable: table, dynamicMap: dynamicMap)
        let score = try Guido.Exporter().convert(standardBeatWork(parts: [part]))
        let intensities = intensities(in: score)

        #expect(intensities.contains { $0.type == "ff" })
        #expect(!symbols(in: score).contains { if case .tag(.dynamicRamp) = $0 { true } else { false } })
    }

    @Test
    func convert_distinctTimeDynamicPair_emitsDynamicRamp() throws {
        var table = NoteTable<BeatTime, Pitch>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(3), pitch: "C4")
        table.insert(attack: BeatTime(3), duration: BeatDuration(1), pitch: "D4")

        var dynamicMap = DynamicMap<BeatTime>()

        dynamicMap.insert(time: BeatTime(0), dynamic: .p)
        dynamicMap.insert(time: BeatTime(3), dynamic: .f)

        let part = Part(name: "", noteTable: table, dynamicMap: dynamicMap)
        let score = try Guido.Exporter().convert(standardBeatWork(parts: [part]))
        let ramp = try #require(symbols(in: score).compactMap { symbol -> GMNDynamicRamp? in
            guard case let .tag(.dynamicRamp(ramp)) = symbol
            else { return nil }

            return ramp
        }.first)

        #expect(ramp.direction == .crescendo)

        // Both endpoints are also written as explicit `\intensity` marks
        // nested inside the ramp's own body, since a hairpin alone carries
        // no target level.
        let nestedIntensities = flatten(ramp.body).compactMap { symbol -> GMNIntensity? in
            guard case let .tag(.intensity(intensity)) = symbol
            else { return nil }

            return intensity
        }

        #expect(nestedIntensities.contains { $0.type == "p" })
        #expect(nestedIntensities.contains { $0.type == "f" })
    }

    @Test
    func convert_emptyWork_producesNoVoices() throws {
        let work = standardBeatWork(parts: [])
        let score = try Guido.Exporter().convert(work)

        #expect(score.voices.isEmpty)
    }

    @Test
    func convert_glissandoNote_exportsAtStartPitch() throws {
        var table = NoteTable<BeatTime, Pitch>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), startPitch: "C4", endPitch: "G4")

        let work = standardBeatWork(parts: [Part(name: "", noteTable: table)])
        let score = try Guido.Exporter().convert(work)
        let note = try #require(symbols(in: score).compactMap { symbol -> GMNNote? in
            guard case let .note(note) = symbol
            else { return nil }

            return note
        }.first)

        #expect(note.pitch.name == .c)
    }

    @Test
    func convert_instrumentMap_recognizedName_emitsMidiProgram() throws {
        var table = NoteTable<BeatTime, Pitch>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: "C4")

        var instrumentMap = InstrumentMap<BeatTime>()

        try instrumentMap.insert(time: BeatTime(0), instrument: #require(Instrument(stringValue: "Acoustic Grand Piano")))

        let part = Part(name: "", noteTable: table, instrumentMap: instrumentMap)
        let score = try Guido.Exporter().convert(standardBeatWork(parts: [part]))
        let instrument = try #require(instruments(in: score).first { $0.instrumentName == "Acoustic Grand Piano" })

        #expect(instrument.midi == 0)
    }

    @Test
    func convert_instrumentMap_unrecognizedName_omitsMidiProgram() throws {
        var table = NoteTable<BeatTime, Pitch>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: "C4")

        var instrumentMap = InstrumentMap<BeatTime>()

        try instrumentMap.insert(time: BeatTime(0), instrument: #require(Instrument(stringValue: "Kazoo Ensemble")))

        let part = Part(name: "", noteTable: table, instrumentMap: instrumentMap)
        let score = try Guido.Exporter().convert(standardBeatWork(parts: [part]))
        let instrument = try #require(instruments(in: score).first { $0.instrumentName == "Kazoo Ensemble" })

        #expect(instrument.midi == nil)
    }

    @Test
    func convert_multiPart_emitsOneVoicePerPart() throws {
        var table1 = NoteTable<BeatTime, Pitch>()

        table1.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: "C4")

        var table2 = NoteTable<BeatTime, Pitch>()

        table2.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: "G4")

        let parts = [Part(name: "Lead", noteTable: table1), Part(name: "Bass", noteTable: table2)]
        let score = try Guido.Exporter().convert(standardBeatWork(parts: parts))

        #expect(score.voices.count == 2)
        #expect(determinePartName(score.voices[0]) == "Lead")
        #expect(determinePartName(score.voices[1]) == "Bass")
    }

    @Test
    func convert_noteCrossingBarline_splitsIntoTiedSegments() throws {
        var table = NoteTable<BeatTime, Pitch>()

        table.insert(attack: BeatTime(3), duration: BeatDuration(2), pitch: "C4")

        let work = standardBeatWork(parts: [Part(name: "", noteTable: table)])
        let score = try Guido.Exporter().convert(work)
        let symbols = symbols(in: score)
        let notes = symbols.compactMap { symbol -> GMNNote? in
            guard case let .note(note) = symbol
            else { return nil }

            return note
        }
        let ties = symbols.filter {
            guard case let .tag(.tie(tie)) = $0
            else { return false }

            return tie.span == .end
        }

        #expect(notes.count == 2)
        #expect(notes.allSatisfy { $0.pitch.name == .c })
        #expect(ties.count == 1)
    }

    @Test
    func convert_shortFinalMeasure_isRestFilled() throws {
        var table = NoteTable<BeatTime, Pitch>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: "C4")

        let work = standardBeatWork(parts: [Part(name: "", noteTable: table)])
        let score = try Guido.Exporter().convert(work)

        #expect(symbols(in: score).contains { if case .rest = $0 { true } else { false } })
    }

    @Test
    func convert_singleNote_emitsNoteSymbol() throws {
        var table = NoteTable<BeatTime, Pitch>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: "C4")

        let work = standardBeatWork(parts: [Part(name: "", noteTable: table)])
        let score = try Guido.Exporter().convert(work)
        let note = try #require(symbols(in: score).compactMap { symbol -> GMNNote? in
            guard case let .note(note) = symbol
            else { return nil }

            return note
        }.first)

        #expect(note.pitch.name == .c)
        #expect(note.pitch.accidental == .omitted)
        #expect(note.pitch.octave?.intValue == 1)
    }

    @Test
    func convert_tempoMap_emitsTempoTag() throws {
        var tempoMap = TempoMap()

        tempoMap.insert(beatTime: BeatTime(0), tempo: Tempo(144))

        // Guido has no header separate from its voices — unlike ABC's `Q:`
        // field, a `\tempo` tag has to live in a voice, so at least one part
        // (even an empty one) is required for the tempo to have anywhere to
        // attach.
        let work = Work(name: "Test", content: .standardBeat([Part(name: "", noteTable: NoteTable())], tempoMap))
        let score = try Guido.Exporter().convert(work)
        let tempo = try #require(symbols(in: score).compactMap { symbol -> GMNTempo? in
            guard case let .tag(.tempo(tempo)) = symbol
            else { return nil }

            return tempo
        }.first)

        #expect(try tempo.metronome == .rate(unit: #require(GMNTempo.Metronome.BeatUnit(1, 4)), beats: 144))
    }

    @Test
    func convert_wallTimeContent_throwsUnsupportedTimeBasis() {
        let work = Work(name: "Test", content: .standardWall([]))

        #expect(throws: Guido.Error.self) {
            try Guido.Exporter().convert(work)
        }
    }

    @Test
    func convert_wrongPitchNotation_throwsUnsupportedPitchNotation() {
        let work = Work(name: "Test", content: .keyboardBeat([], TempoMap()))

        #expect(throws: Guido.Error.self) {
            try Guido.Exporter().convert(work)
        }
    }

    @Test
    func writableFileFormats_containsGMN() {
        #expect(Guido.Exporter().writableFileFormats == [.gmn])
    }

    @Test
    func write_emptyWorks_throwsNoWorksToExport() {
        #expect(throws: Guido.Error.self) {
            try Guido.Exporter().write(works: [], as: .gmn)
        }
    }

    @Test
    func write_multipleWorks_throwsMultipleWorksNotSupported() {
        let works = [standardBeatWork(parts: []), standardBeatWork(parts: [])]

        #expect(throws: Guido.Error.self) {
            try Guido.Exporter().write(works: works, as: .gmn)
        }
    }

    @Test
    func write_singleWork_succeeds() throws {
        var table = NoteTable<BeatTime, Pitch>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: "C4")

        let work = standardBeatWork(parts: [Part(name: "", noteTable: table)])
        let file = try Guido.Exporter().write(works: [work], as: .gmn)

        #expect(file.regularFileContents != nil)
    }

    @Test
    func write_unsupportedFormat_throws() {
        #expect(throws: Guido.Error.self) {
            try Guido.Exporter().write(works: [standardBeatWork(parts: [])], as: .midi)
        }
    }
}
