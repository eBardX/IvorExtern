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

// swiftlint:disable file_length

// This exporter declares an explicit `V:` for every part except a lone,
// unnamed one (see `ABC.Exporter._needsVoiceFields(parts:)`) and switches
// into it before the first symbol, so a named/multi-part work never lands
// in `ABC.Importer.Walker._routed(_:fileHeader:)`'s implicit "voice 0"
// accumulator — `ABC.Importer._isEmptyImplicitVoice` drops it and every
// part below comes back exactly as written. Tests still look their part up
// by name rather than by index, matching `JohnnySonicRoundTripTests`
// routing around that format's own by-instrument part grouping — not
// working around anything here, just resilient to part order.
struct ABCExporterTests {
}

// MARK: -

extension ABCExporterTests {
    @Test
    func convert_articulationExtra_writesItsTextAsADecoration() throws {
        var table = NoteTable<BeatTime, Pitch>()

        table.insert(attack: .zero,
                     duration: BeatDuration(1),
                     pitch: "C4",
                     extras: Extras(elements: [Extra(name: Extra.articulation.name, values: [.string("flick")])]))

        let tune = try ABC.Exporter().convert(standardBeatWork(parts: [Part(name: "", noteTable: table)]))

        #expect(decorations(in: tune).contains { $0.name.stringValue == "flick" })
    }

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
    func convert_dynamicMarkExtra_emitsLiteralDecorationText() throws {
        var table = NoteTable<BeatTime, Pitch>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: "C4")

        var dynamicMap = DynamicMap<BeatTime>()

        dynamicMap.insert(time: BeatTime(0),
                          dynamic: .mp,
                          extras: Extras(elements: [Extra(name: Extra.dynamicMark.name, values: [.string("sfz")])]))

        let part = Part(name: "", noteTable: table, dynamicMap: dynamicMap)
        let tune = try ABC.Exporter().convert(standardBeatWork(parts: [part]))
        let decorations = decorations(in: tune)

        #expect(decorations.contains { $0.name.stringValue == "sfz" })
    }

    @Test
    func convert_emptyWork_producesHeaderOnlyTune() throws {
        let work = standardBeatWork(parts: [])
        let tune = try ABC.Exporter().convert(work)

        #expect(!tune.header.isEmpty)
        #expect(symbols(in: tune).isEmpty)
    }

    @Test
    func convert_fallbackPartName_omitsNameAndRoundTrips() throws {
        var table = NoteTable<BeatTime, Pitch>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: "C4")

        let parts = [Part(name: "Voice 1", noteTable: table), Part(name: "Bass", noteTable: table)]
        let file = try ABC.Exporter().write(works: [standardBeatWork(parts: parts)], as: .abc)
        let text = try #require(file.regularFileContents.flatMap { String(bytes: $0, encoding: .utf8) })
        let work = try #require(try ABC.Importer().read(from: file, as: .abc).first)

        #expect(!text.contains("Voice 1"))
        #expect(try #require(standardBeatParts(of: work)).map(\.name) == ["Voice 1", "Bass"])
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
    func convert_instrumentTable_midiBankExtra_emitsProgramThenVoiceDirective() throws {
        var table = NoteTable<BeatTime, Pitch>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: "C4")

        var instrumentTable = InstrumentTable<BeatTime>()

        try instrumentTable.insert(time: BeatTime(0),
                                   instrument: #require(Instrument(stringValue: "Church Organ")),
                                   extras: Extras(elements: [Extra(name: Extra.midiProgram.name, values: [.int(20)]),
                                                             Extra(name: Extra.midiBank.name, values: [.int(8)])]))

        let part = Part(name: "", noteTable: table, instrumentTable: instrumentTable)
        let tune = try ABC.Exporter().convert(standardBeatWork(parts: [part]))
        let values = tune.body.compactMap { entry -> String? in
            guard case let .directive(directive) = entry
            else { return nil }

            return directive.value
        }

        #expect(values == ["program 20", "voice instrument=20 bank=9"])
    }

    @Test
    func convert_instrumentTable_midiChannelExtra_emitsChannelToken() throws {
        var table = NoteTable<BeatTime, Pitch>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: "C4")

        var instrumentTable = InstrumentTable<BeatTime>()

        try instrumentTable.insert(time: BeatTime(0),
                                   instrument: #require(Instrument(stringValue: "Acoustic Grand Piano")))

        let part = Part(name: "", noteTable: table, instrumentTable: instrumentTable, extras: channelExtras(5))
        let tune = try ABC.Exporter().convert(standardBeatWork(parts: [part]))
        let directive = try #require(tune.body.compactMap { entry -> ABCDirective? in
            guard case let .directive(directive) = entry
            else { return nil }

            return directive
        }.first)

        #expect(directive.value == "program 5 1")
    }

    @Test
    func convert_instrumentTable_recognizedName_emitsMidiDirective() throws {
        var table = NoteTable<BeatTime, Pitch>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: "C4")

        var instrumentTable = InstrumentTable<BeatTime>()

        try instrumentTable.insert(time: BeatTime(0), instrument: #require(Instrument(stringValue: "Acoustic Grand Piano")))

        let part = Part(name: "", noteTable: table, instrumentTable: instrumentTable)
        let tune = try ABC.Exporter().convert(standardBeatWork(parts: [part]))
        let directive = try #require(tune.body.compactMap { entry -> ABCDirective? in
            guard case let .directive(directive) = entry
            else { return nil }

            return directive
        }.first)

        #expect(directive.name.stringValue.lowercased() == "midi")
        #expect(directive.value == "program 1")
    }

    @Test
    func convert_instrumentTable_recognizedName_emitsProgramBaseOneInHeader() throws {
        var table = NoteTable<BeatTime, Pitch>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: "C4")

        var instrumentTable = InstrumentTable<BeatTime>()

        try instrumentTable.insert(time: BeatTime(0), instrument: #require(Instrument(stringValue: "Violin")))

        let part = Part(name: "", noteTable: table, instrumentTable: instrumentTable)
        let tune = try ABC.Exporter().convert(standardBeatWork(parts: [part]))
        let values = tune.header.compactMap { entry -> String? in
            guard case let .directive(directive) = entry
            else { return nil }

            return directive.value
        }

        #expect(values == ["programbase 1"])
    }

    @Test
    func convert_instrumentTable_unrecognizedName_omitsDirective() throws {
        var table = NoteTable<BeatTime, Pitch>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: "C4")

        var instrumentTable = InstrumentTable<BeatTime>()

        try instrumentTable.insert(time: BeatTime(0), instrument: #require(Instrument(stringValue: "Kazoo Ensemble")))

        let part = Part(name: "", noteTable: table, instrumentTable: instrumentTable)
        let tune = try ABC.Exporter().convert(standardBeatWork(parts: [part]))

        #expect(!tune.body.contains { if case .directive = $0 { true } else { false } })
        #expect(!tune.header.contains { if case .directive = $0 { true } else { false } })
    }

    @Test
    func convert_instrumentTable_unrecognizedNameWithMidiChannelExtra_emitsStandaloneChannelDirective() throws {
        var table = NoteTable<BeatTime, Pitch>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: "C4")

        var instrumentTable = InstrumentTable<BeatTime>()

        try instrumentTable.insert(time: BeatTime(0),
                                   instrument: #require(Instrument(stringValue: "Kazoo Ensemble")))

        let part = Part(name: "", noteTable: table, instrumentTable: instrumentTable, extras: channelExtras(3))
        let tune = try ABC.Exporter().convert(standardBeatWork(parts: [part]))
        let directive = try #require(tune.body.compactMap { entry -> ABCDirective? in
            guard case let .directive(directive) = entry
            else { return nil }

            return directive
        }.first)

        #expect(directive.value == "channel 3")
    }

    @Test
    func convert_midiChannelExtraWithoutInstrumentTable_emitsStandaloneChannelDirective() throws {
        var table = NoteTable<BeatTime, Pitch>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: "C4")

        let part = Part(name: "", noteTable: table, extras: channelExtras(4))
        let tune = try ABC.Exporter().convert(standardBeatWork(parts: [part]))
        let directives = tune.body.compactMap { entry -> ABCDirective? in
            guard case let .directive(directive) = entry
            else { return nil }

            return directive
        }

        #expect(directives.map(\.value) == ["channel 4"])
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
    func convert_stepAfterLeadingEntry_emitsMarksAndNoHairpin() throws {
        var table = NoteTable<BeatTime, Pitch>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(4), pitch: "C4")
        table.insert(attack: BeatTime(4), duration: BeatDuration(4), pitch: "D4")

        var dynamicMap = DynamicMap<BeatTime>()

        dynamicMap.insert(time: BeatTime(0), dynamic: .p)
        dynamicMap.insert(time: BeatTime(4), dynamic: .p)
        dynamicMap.insert(time: BeatTime(4), dynamic: .f)

        let part = Part(name: "", noteTable: table, dynamicMap: dynamicMap)
        let tune = try ABC.Exporter().convert(standardBeatWork(parts: [part]))
        let names = decorations(in: tune).map(\.name.stringValue)

        #expect(names.contains("p"))
        #expect(names.contains("f"))
        #expect(!names.contains { $0.hasPrefix("crescendo") || $0.hasPrefix("diminuendo") })
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
    func roundTrip_articulationAndSlur_preservesFlags() throws {
        var table = NoteTable<BeatTime, Pitch>()

        table.insert(attack: BeatTime(0),
                     duration: BeatDuration(1),
                     pitch: "C4",
                     extras: Extras(elements: [Extra(name: Extra.accent.name, values: []),
                                               Extra(name: Extra.slurStart.name, values: [])]))
        table.insert(attack: BeatTime(1),
                     duration: BeatDuration(1),
                     pitch: "D4",
                     extras: Extras(elements: [Extra(name: Extra.slurEnd.name, values: [])]))

        let part = Part(name: "Piano", noteTable: table)
        let work = Work(name: "Articulation", content: .standardBeat([part], TempoMap()))

        let recovered = try roundTrip(work,
                                      exporter: ABC.Exporter(),
                                      importer: ABC.Importer(),
                                      fileFormat: .abc)
        let recoveredPart = try namedStandardPart(recovered, "Piano")

        var flags: [(accent: Bool, slurStart: Bool, slurEnd: Bool)] = []

        for note in recoveredPart.noteTable {
            flags.append((hasFlag(note.extras, .accent), hasFlag(note.extras, .slurStart), hasFlag(note.extras, .slurEnd)))
        }

        #expect(flags.count == 2)
        #expect(flags[0].accent)
        #expect(flags[0].slurStart)
        #expect(flags[1].slurEnd)
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
                                      exporter: ABC.Exporter(),
                                      importer: ABC.Importer(),
                                      fileFormat: .abc)
        let recoveredPart = try namedStandardPart(recovered, "Piano")

        expectNoteTablesMatch(recoveredPart.noteTable, table)
    }

    @Test
    func roundTrip_eighthNotes_keepPlainLengths() throws {
        var table = NoteTable<BeatTime, Pitch>()
        let half = Number(numerator: 1, denominator: 2)

        table.insert(attack: .zero, duration: BeatDuration(half), pitch: "C4")
        table.insert(attack: BeatTime(half), duration: BeatDuration(half), pitch: "D4")

        let work = standardBeatWork(parts: [Part(name: "", noteTable: table)])
        let tune = try ABC.Exporter().convert(work)
        let recovered = try roundTrip(work,
                                      exporter: ABC.Exporter(),
                                      importer: ABC.Importer(),
                                      fileFormat: .abc)
        let part = try #require(standardBeatParts(of: recovered)?.first)

        #expect(!symbols(in: tune).contains { if case .tuplet = $0 { true } else { false } })
        #expect(part.noteTable.map(\.attack) == [.zero, BeatTime(half)])
        #expect(part.noteTable.map(\.duration) == [BeatDuration(half), BeatDuration(half)])
    }

    @Test
    func roundTrip_info_preservesWhatABCCanHold() throws {
        let part = Part<BeatTime, Pitch>(name: "Flute",
                                         noteTable: NoteTable())
        let work = Work(name: "Aubade",
                        content: .standardBeat([part], TempoMap()),
                        info: sampleABCInfo())
        let recovered = try roundTrip(work,
                                      exporter: ABC.Exporter(),
                                      importer: ABC.Importer(),
                                      fileFormat: .abc)
        let info = recovered.info

        #expect(info.title == "Aubade")
        #expect(info.alternateTitles == ["Dawn Song", "Morning Piece"])
        #expect(info.subtitles.isEmpty)
        #expect(info.parentWorkTitle == nil)
        #expect(info.dedication == "To my teacher with thanks")
        #expect(info.credits == [Credit(name: "J. Smith", role: .composer),
                                 Credit(name: "A. Poet (lyricist)", role: .composer),
                                 Credit(name: "T. Scribe", role: .transcriber)].compactMap(\.self))
        #expect(info.rights == [RightsNotice(text: "© 2001 T. Scribe", scope: .transcription)].compactMap(\.self))
        #expect(info.remarks == [Remark(text: "Collected in 1904 by a fiddler", label: "history"),
                                 Remark(text: "From a fiddler", label: "source"),
                                 Remark(text: "A plain remark"),
                                 Remark(text: "mood: Wistful", label: "notes")].compactMap(\.self))
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
                                      exporter: ABC.Exporter(),
                                      importer: ABC.Importer(),
                                      fileFormat: .abc)
        let recoveredPart = try namedStandardPart(recovered, "Piano")

        var instruments: [Instrument] = []

        for entry in recoveredPart.instrumentTable {
            instruments.append(entry.instrument)
        }

        #expect(instruments.first?.stringValue == "Acoustic Grand Piano")
    }

    @Test
    func roundTrip_midiBank_preservesEachPartsInstrumentAndBank() throws {
        var table = NoteTable<BeatTime, Pitch>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: "C4")

        var organMap = InstrumentTable<BeatTime>()

        try organMap.insert(time: BeatTime(0),
                            instrument: #require(Instrument(stringValue: "Church Organ")),
                            extras: Extras(elements: [Extra(name: Extra.midiProgram.name, values: [.int(20)]),
                                                      Extra(name: Extra.midiBank.name, values: [.int(8)])]))

        var fluteMap = InstrumentTable<BeatTime>()

        try fluteMap.insert(time: BeatTime(0),
                            instrument: #require(Instrument(stringValue: "Flute")),
                            extras: Extras(elements: [Extra(name: Extra.midiProgram.name, values: [.int(74)]),
                                                      Extra(name: Extra.midiBank.name, values: [.int(0)])]))

        let parts = [Part(name: "Organ", noteTable: table, instrumentTable: organMap),
                     Part(name: "Flute", noteTable: table, instrumentTable: fluteMap)]
        let work = Work(name: "Banks", content: .standardBeat(parts, TempoMap()))

        let recovered = try roundTrip(work,
                                      exporter: ABC.Exporter(),
                                      importer: ABC.Importer(),
                                      fileFormat: .abc)

        var found: [(String, Int?)] = []

        for name in ["Organ", "Flute"] {
            for entry in try namedStandardPart(recovered, name).instrumentTable {
                found.append((entry.instrument.stringValue, intValue(entry.extras, .midiBank)))
            }
        }

        #expect(found.map(\.0) == ["Church Organ", "Flute"])
        #expect(found.map(\.1) == [8, 0])
    }

    @Test
    func roundTrip_multiPart_preservesEachPartsInstrument() throws {
        var table = NoteTable<BeatTime, Pitch>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: "C4")

        var parts: [Part<BeatTime, Pitch>] = []

        for name in ["Flute", "Bassoon"] {
            var instrumentTable = InstrumentTable<BeatTime>()

            try instrumentTable.insert(time: BeatTime(0), instrument: #require(Instrument(stringValue: name)))
            parts.append(Part(name: name, noteTable: table, instrumentTable: instrumentTable))
        }

        let work = Work(name: "Duet", content: .standardBeat(parts, TempoMap()))

        let recovered = try roundTrip(work,
                                      exporter: ABC.Exporter(),
                                      importer: ABC.Importer(),
                                      fileFormat: .abc)

        #expect(try namedStandardPart(recovered, "Flute").instrumentTable[.zero] == Instrument("Flute"))
        #expect(try namedStandardPart(recovered, "Bassoon").instrumentTable[.zero] == Instrument("Bassoon"))
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
                                      exporter: ABC.Exporter(),
                                      importer: ABC.Importer(),
                                      fileFormat: .abc)
        let recoveredTempoMap = try #require(recovered.tempoMap)

        var foundText: String?

        for entry in recoveredTempoMap where entry.beatTime == BeatTime(0) {
            foundText = stringValue(entry.extras, .tempoText)
        }

        #expect(foundText == "Allegro")
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

    @Test
    func roundTrip_tupletRest_keepsTheNextNoteInPlace() throws {
        var table = NoteTable<BeatTime, Pitch>()

        table.insert(attack: .zero, duration: BeatDuration(Number(numerator: 1, denominator: 3)), pitch: "C4")
        table.insert(attack: BeatTime(1), duration: BeatDuration(1), pitch: "D4")

        let recovered = try roundTrip(standardBeatWork(parts: [Part(name: "", noteTable: table)]),
                                      exporter: ABC.Exporter(),
                                      importer: ABC.Importer(),
                                      fileFormat: .abc)
        let part = try #require(standardBeatParts(of: recovered)?.first)

        #expect(part.noteTable.map(\.attack) == [.zero, BeatTime(1)])
    }

    @Test
    func roundTrip_tupletWithAnEvenDenominator_preservesDuration() throws {
        var table = NoteTable<BeatTime, Pitch>()
        let sixth = Number(numerator: 1, denominator: 6)

        table.insert(attack: .zero, duration: BeatDuration(sixth), pitch: "C4")

        let recovered = try roundTrip(standardBeatWork(parts: [Part(name: "", noteTable: table)]),
                                      exporter: ABC.Exporter(),
                                      importer: ABC.Importer(),
                                      fileFormat: .abc)
        let part = try #require(standardBeatParts(of: recovered)?.first)

        #expect(part.noteTable.map(\.duration) == [BeatDuration(sixth)])
    }

    @Test
    func writableFileFormats_containsABC() {
        #expect(ABC.Exporter().writableFileFormats == [.abc])
    }

    @Test
    func write_editorCredit_writesEditedByField() throws {
        var info = Work.Info()

        info.credits = [Credit(name: "J. Editor", role: .editor)].compactMap(\.self)

        let text = try writeABC(Work(name: "Sketch",
                                     content: .standardBeat([], TempoMap()),
                                     info: info))

        #expect(text.split(separator: "\n").contains("Z:abc-edited-by J. Editor"))
    }

    @Test
    func write_emptyWorks_throwsNoWorksToExport() {
        #expect(throws: ABC.Error.self) {
            try ABC.Exporter().write(works: [], as: .abc)
        }
    }

    @Test
    func write_info_writesStringFields() throws {
        let text = try writeABC(Work(name: "Sketch",
                                     content: .standardBeat([], TempoMap()),
                                     info: sampleABCInfo()))
        let lines = text.split(separator: "\n").map(String.init)

        #expect(lines.prefix(5) == ["%abc-2.1", "X:1", "T:Aubade", "T:Dawn Song", "T:Morning Piece"])
        #expect(lines.contains("N:dedication: To my teacher with thanks"))
        #expect(lines.contains("C:J. Smith"))
        #expect(lines.contains("C:A. Poet (lyricist)"))
        #expect(lines.contains("Z:T. Scribe"))
        #expect(lines.contains("Z:abc-copyright © 2001 T. Scribe"))
        #expect(lines.contains("H:Collected in 1904 by a fiddler"))
        #expect(lines.contains("S:From a fiddler"))
        #expect(lines.contains("r:A plain remark"))
        #expect(lines.contains("N:mood: Wistful"))
        #expect(!text.contains("© 1998 Acme"))
        #expect(!text.contains("Collected Pieces"))
    }

    @Test(arguments: [(RemarkLabel.area, "A"),
                      (RemarkLabel.book, "B"),
                      (RemarkLabel.discography, "D"),
                      (RemarkLabel.fileURL, "F"),
                      (RemarkLabel.group, "G"),
                      (RemarkLabel.notes, "N"),
                      (RemarkLabel.origin, "O"),
                      (RemarkLabel.rhythm, "R")])
    func write_labeledRemark_writesItsOwnField(label: String, field: String) throws {
        var info = Work.Info()

        info.remarks = [Remark(text: "Some text", label: label)].compactMap(\.self)

        let text = try writeABC(Work(name: "Sketch",
                                     content: .standardBeat([], TempoMap()),
                                     info: info))

        #expect(text.split(separator: "\n").contains("\(field):Some text"[...]))
    }

    @Test
    func write_multipleWorks_succeeds() throws {
        let works = [standardBeatWork(parts: []), standardBeatWork(parts: [])]
        let file = try ABC.Exporter().write(works: works, as: .abc)

        #expect(file.regularFileContents != nil)
    }

    @Test
    func write_noTitle_writesWorkNameAsTitle() throws {
        let text = try writeABC(Work(name: "Sketch 3", content: .standardBeat([], TempoMap())))

        #expect(text.contains("T:Sketch 3\n"))
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

// swiftlint:enable file_length
