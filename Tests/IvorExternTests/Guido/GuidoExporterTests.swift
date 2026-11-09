// © 2026 John Gary Pusey (see LICENSE.md)

import Foundation
@testable import IvorExtern
import IvorGMN
import IvorModel
import IvorTiming
import IvorTuning
import Testing
import XestiNumbers
import XestiTools

// swiftlint:disable file_length

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
    func convert_dynamicMarkExtra_emitsLiteralIntensityText() throws {
        var table = NoteTable<BeatTime, Pitch>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: "C4")

        var dynamicMap = DynamicMap<BeatTime>()

        dynamicMap.insert(time: BeatTime(0),
                          dynamic: .mp,
                          extras: Extras(elements: [Extra(name: Extra.dynamicMark.name, values: [.string("sfz")])]))

        let part = Part(name: "", noteTable: table, dynamicMap: dynamicMap)
        let score = try Guido.Exporter().convert(standardBeatWork(parts: [part]))
        let intensities = intensities(in: score)

        #expect(intensities.contains { $0.type == "sfz" })
    }

    @Test
    func convert_emptyWork_producesNoVoices() throws {
        let work = standardBeatWork(parts: [])
        let score = try Guido.Exporter().convert(work)

        #expect(score.voices.isEmpty)
    }

    @Test
    func convert_fallbackPartName_roundTripsWithoutInstrument() throws {
        var table = NoteTable<BeatTime, Pitch>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: "C4")

        let parts = [Part(name: "Voice 1", noteTable: table), Part(name: "Bass", noteTable: table)]
        let score = try Guido.Exporter().convert(standardBeatWork(parts: parts))
        let work = try Guido.Importer().convert(score)

        guard case let .standardBeat(imported, _) = work.content
        else { Issue.record("Expected standardBeat content"); return }

        #expect(imported.map(\.name) == ["Voice 1", "Bass"])
        #expect(imported.first?.instrumentTable.isEmpty == true)
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
    func convert_instrumentTable_recognizedName_emitsMidiProgram() throws {
        var table = NoteTable<BeatTime, Pitch>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: "C4")

        var instrumentTable = InstrumentTable<BeatTime>()

        try instrumentTable.insert(time: BeatTime(0), instrument: #require(Instrument(stringValue: "Acoustic Grand Piano")))

        let part = Part(name: "", noteTable: table, instrumentTable: instrumentTable)
        let score = try Guido.Exporter().convert(standardBeatWork(parts: [part]))
        let instrument = try #require(instruments(in: score).first { $0.instrumentName == "Acoustic Grand Piano" })

        #expect(instrument.midi == 0)
    }

    @Test
    func convert_instrumentTable_unrecognizedName_omitsMidiProgram() throws {
        var table = NoteTable<BeatTime, Pitch>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: "C4")

        var instrumentTable = InstrumentTable<BeatTime>()

        try instrumentTable.insert(time: BeatTime(0), instrument: #require(Instrument(stringValue: "Kazoo Ensemble")))

        let part = Part(name: "", noteTable: table, instrumentTable: instrumentTable)
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
                                      exporter: Guido.Exporter(),
                                      importer: Guido.Importer(),
                                      fileFormat: .gmn)
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
                                      exporter: Guido.Exporter(),
                                      importer: Guido.Importer(),
                                      fileFormat: .gmn)
        let recoveredPart = try #require(standardBeatParts(of: recovered)?.first)

        expectNoteTablesMatch(recoveredPart.noteTable, table)
    }

    @Test
    func roundTrip_info_preservesWhatGuidoCanHold() throws {
        let work = Work(name: "Aubade: Dawn Song: Morning Piece",
                        content: .standardBeat([Part(name: "", noteTable: NoteTable())], TempoMap()),
                        info: sampleGuidoInfo())
        let recovered = try roundTrip(work,
                                      exporter: Guido.Exporter(),
                                      importer: Guido.Importer(),
                                      fileFormat: .gmn)
        let info = recovered.info

        #expect(recovered.name == work.name)
        #expect(info.title == "Aubade")
        #expect(info.subtitles == ["Dawn Song", "Morning Piece"])
        #expect(info.alternateTitles.isEmpty)
        #expect(info.parentWorkTitle == nil)
        #expect(info.dedication == nil)
        #expect(info.credits == [Credit(name: "J. Smith", role: .composer),
                                 Credit(name: "A. Poet (lyricist)", role: .composer)].compactMap(\.self))
        #expect(info.rights == [RightsNotice(text: "© 1998 Acme Line two")].compactMap(\.self))
        #expect(info.remarks == [Remark(text: "Engraved by hand", label: "footer"),
                                 Remark(text: "Theme", label: "label")].compactMap(\.self))
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
                                      exporter: Guido.Exporter(),
                                      importer: Guido.Importer(),
                                      fileFormat: .gmn)
        let recoveredPart = try #require(standardBeatParts(of: recovered)?.first)

        var instruments: [Instrument] = []

        for entry in recoveredPart.instrumentTable {
            instruments.append(entry.instrument)
        }

        #expect(instruments.contains { $0.stringValue == "Acoustic Grand Piano" })
    }

    // Each part's own `\instrument`-derived name is voice-scoped, so
    // multiple parts recover independently and in order — unlike
    // `ABCRoundTripTests`, there's no importer-side quirk to route around
    // here.
    @Test
    func roundTrip_multiPart_preservesEachPartsNotes() throws {
        var table1 = NoteTable<BeatTime, Pitch>()

        table1.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: "C4")

        var table2 = NoteTable<BeatTime, Pitch>()

        table2.insert(attack: BeatTime(0), duration: BeatDuration(2), pitch: "G3")

        let parts = [Part(name: "Lead", noteTable: table1), Part(name: "Bass", noteTable: table2)]
        let work = Work(name: "MultiPart", content: .standardBeat(parts, TempoMap()))

        let recovered = try roundTrip(work,
                                      exporter: Guido.Exporter(),
                                      importer: Guido.Importer(),
                                      fileFormat: .gmn)
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
                                      exporter: Guido.Exporter(),
                                      importer: Guido.Importer(),
                                      fileFormat: .gmn)
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
                                      exporter: Guido.Exporter(),
                                      importer: Guido.Importer(),
                                      fileFormat: .gmn)
        let recoveredPart = try #require(standardBeatParts(of: recovered)?.first)

        expectNoteTablesMatch(recoveredPart.noteTable, table)
    }

    @Test
    func roundTrip_pizzicatoVariants_preservesTypes() throws {
        var table = NoteTable<BeatTime, Pitch>()

        table.insert(attack: BeatTime(0),
                     duration: BeatDuration(1),
                     pitch: "C4",
                     extras: Extras(elements: [.pizzicato]))
        table.insert(attack: BeatTime(1),
                     duration: BeatDuration(1),
                     pitch: "D4",
                     extras: Extras(elements: [Extra(name: Extra.articulation.name, values: [.string("snapPizzicato")])]))
        table.insert(attack: BeatTime(2),
                     duration: BeatDuration(1),
                     pitch: "E4",
                     extras: Extras(elements: [Extra(name: Extra.articulation.name, values: [.string("bow")])]))

        let part = Part(name: "Violin", noteTable: table)
        let work = Work(name: "Pizzicato", content: .standardBeat([part], TempoMap()))

        let recovered = try roundTrip(work,
                                      exporter: Guido.Exporter(),
                                      importer: Guido.Importer(),
                                      fileFormat: .gmn)
        let recoveredPart = try #require(standardBeatParts(of: recovered)?.first)

        var flags: [(pizzicato: Bool, articulation: String?)] = []

        for note in recoveredPart.noteTable {
            flags.append((hasFlag(note.extras, .pizzicato), stringValue(note.extras, .articulation)))
        }

        #expect(flags.count == 3)
        #expect(flags[0].pizzicato)
        #expect(flags[0].articulation == nil)
        #expect(!flags[1].pizzicato)
        #expect(flags[1].articulation == "snapPizzicato")
        #expect(flags[2].articulation == nil)   // Guido has no tag for a free-text articulation
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
                                      exporter: Guido.Exporter(),
                                      importer: Guido.Importer(),
                                      fileFormat: .gmn)
        let recoveredTempoMap = try #require(recovered.tempoMap)

        #expect(recoveredTempoMap[BeatTime(0)] == Tempo(96))
    }

    @Test
    func roundTrip_tempoText_preservesLabel() throws {
        var tempoMap = TempoMap()

        tempoMap.insert(beatTime: BeatTime(0),
                        tempo: Tempo(120),
                        extras: Extras(elements: [Extra(name: Extra.tempoText.name, values: [.string("Allegro")])]))

        var table = NoteTable<BeatTime, Pitch>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: "C4")

        let part = Part(name: "Piano", noteTable: table)
        let work = Work(name: "TempoText", content: .standardBeat([part], tempoMap))

        let recovered = try roundTrip(work,
                                      exporter: Guido.Exporter(),
                                      importer: Guido.Importer(),
                                      fileFormat: .gmn)
        let recoveredTempoMap = try #require(recovered.tempoMap)

        var foundText: String?

        for entry in recoveredTempoMap where entry.beatTime == BeatTime(0) {
            foundText = stringValue(entry.extras, .tempoText)
        }

        #expect(foundText == "Allegro")
    }

    // A duration whose fraction of a whole note has no power-of-2
    // denominator has no plain ABC spelling, but `GMNDuration` accepts any
    // non-zero rational directly — no tuplet reconstruction is needed.
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
                                      exporter: Guido.Exporter(),
                                      importer: Guido.Importer(),
                                      fileFormat: .gmn)
        let recoveredPart = try #require(standardBeatParts(of: recovered)?.first)

        expectNoteTablesMatch(recoveredPart.noteTable, table)
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
    func write_info_writesLeadingTagsOfFirstVoice() throws {
        let score = try Guido.Exporter().convert(Work(name: "Sketch",
                                                      content: .standardBeat([Part(name: "", noteTable: NoteTable())], TempoMap()),
                                                      info: sampleGuidoInfo()))
        let tags = try #require(score.voices.first).symbols.compactMap { symbol -> String? in
            switch symbol {
            case let .tag(.titleBlock(block)):
                "\(block.kind):\(block.text)"

            case let .tag(.text(text)):
                "\(text.kind):\(text.text)"

            default:
                nil
            }
        }

        #expect(tags == ["title:Aubade",
                         "title:Dawn Song",
                         "title:Morning Piece",
                         "composer:J. Smith",
                         "composer:A. Poet (lyricist)",
                         "footer:© 1998 Acme Line two",
                         "footer:Engraved by hand",
                         "label:Theme"])
    }

    @Test
    func write_instrumentNameExtra_namesInstrumentTag() throws {
        var instrumentTable = InstrumentTable<BeatTime>()

        instrumentTable.insert(time: .zero,
                               instrument: Instrument("Flute"),
                               extras: Extras(elements: [Extra(name: Extra.instrumentName.name, values: [.string("Flauto 1")])]))

        let part = Part<BeatTime, Pitch>(name: "", noteTable: NoteTable(), instrumentTable: instrumentTable)
        let score = try Guido.Exporter().convert(Work(name: "", content: .standardBeat([part], TempoMap())))

        #expect(instruments(in: score).map(\.instrumentName) == ["Flauto 1"])
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

// swiftlint:enable file_length
