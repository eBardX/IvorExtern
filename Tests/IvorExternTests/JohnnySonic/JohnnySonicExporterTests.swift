// © 2025–2026 John Gary Pusey (see LICENSE.md)

import Foundation
import IvorDKM
@testable import IvorExtern
import IvorModel
import IvorTiming
import IvorTuning
import Testing
import XestiNumbers
import XestiTools

struct JohnnySonicExporterTests {
}

// MARK: -

extension JohnnySonicExporterTests {
    @Test
    func convert_absoluteBeatWork_empty() throws {
        let work = Work(name: "Test",
                        content: .absoluteBeat([] as [Part<BeatTime, Frequency>],
                                               TempoMap()))

        _ = try JohnnySonic.Exporter().convert(work)
    }

    @Test
    func convert_absoluteBeatWork_note_emitsPitchesNote() throws {
        var table = NoteTable<BeatTime, Frequency>()

        try table.insert(attack: BeatTime(0),
                         duration: BeatDuration(1),
                         pitch: #require(Frequency(numberValue: Number(440.0))))

        let part = Part(name: "Tone", noteTable: table)
        let work = Work(name: "Test",
                        content: .absoluteBeat([part], TempoMap()))
        let score = try JohnnySonic.Exporter().convert(work)

        let notes = score.commands.compactMap { command -> DKMPitchesNote? in
            guard case let .pitchesNote(note) = command
            else { return nil }

            return note
        }

        #expect(notes.count == 1)
        #expect(notes[0].startPitch == -440.0)
    }

    @Test
    func convert_dynamics_emittedOnNote() throws {
        var table = NoteTable<BeatTime, NoteNumber>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: NoteNumber(60))

        var dynamicMap = DynamicMap<BeatTime>()

        try dynamicMap.insert(time: BeatTime(0), dynamic: #require(Dynamic(numberValue: Number(0.5))))

        let part = Part(name: "Piano", noteTable: table, dynamicMap: dynamicMap)
        let work = Work(name: "Test", content: .keyboardBeat([part], TempoMap()))
        let score = try JohnnySonic.Exporter().convert(work)

        let notes = score.commands.compactMap { command -> DKMPitchesNote? in
            guard case let .pitchesNote(note) = command
            else { return nil }

            return note
        }

        #expect(notes.count == 1)
        #expect(notes[0].volume == 5.0)
    }

    @Test
    func convert_instrument_emittedOnNote() throws {
        var table = NoteTable<BeatTime, NoteNumber>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: NoteNumber(60))

        var instrumentTable = InstrumentTable<BeatTime>()

        try instrumentTable.insert(time: BeatTime(0), instrument: #require(Instrument(stringValue: "Flute")))

        let part = Part(name: "Piano", noteTable: table, instrumentTable: instrumentTable)
        let work = Work(name: "Test", content: .keyboardBeat([part], TempoMap()))
        let score = try JohnnySonic.Exporter().convert(work)

        let notes = score.commands.compactMap { command -> DKMPitchesNote? in
            guard case let .pitchesNote(note) = command
            else { return nil }

            return note
        }

        #expect(notes.count == 1)
        #expect(notes[0].instrument == "Flute")
    }

    @Test
    func convert_keyboardBeat_note_emitsPitchesNote() throws {
        var table = NoteTable<BeatTime, NoteNumber>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: NoteNumber(60))

        let part = Part(name: "Piano", noteTable: table)
        let work = Work(name: "Test", content: .keyboardBeat([part], TempoMap()))
        let score = try JohnnySonic.Exporter().convert(work)

        let notes = score.commands.compactMap { command -> DKMPitchesNote? in
            guard case let .pitchesNote(note) = command
            else { return nil }

            return note
        }

        #expect(notes.count == 1)
        #expect(notes[0].startPitch == 60.0)
        #expect(notes[0].duration == 1.0)
    }

    @Test
    func convert_noteVelocity_winsOverDynamic() throws {
        var table = NoteTable<BeatTime, NoteNumber>()

        table.insert(attack: BeatTime(0),
                     duration: BeatDuration(1),
                     pitch: NoteNumber(60),
                     extras: Extras(elements: [Extra(name: Extra.attackVelocity.name, values: [.int(100)])]))

        var dynamicMap = DynamicMap<BeatTime>()

        dynamicMap.insert(time: BeatTime(0), dynamic: .pp)

        let part = Part(name: "Piano", noteTable: table, dynamicMap: dynamicMap)
        let work = Work(name: "Test", content: .keyboardBeat([part], TempoMap()))
        let score = try JohnnySonic.Exporter().convert(work)

        let notes = score.commands.compactMap { command -> DKMPitchesNote? in
            guard case let .pitchesNote(note) = command
            else { return nil }

            return note
        }

        #expect(notes.map(\.volume) == [Double(100) / 12.7])
    }

    @Test
    func convert_pan_emittedOnNote() throws {
        var table = NoteTable<BeatTime, NoteNumber>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: NoteNumber(60))

        var panMap = PanMap<BeatTime>()

        panMap.insert(time: BeatTime(0), pan: Pan(horizontal: -45))

        let part = Part(name: "Piano", noteTable: table, panMap: panMap)
        let work = Work(name: "Test", content: .keyboardBeat([part], TempoMap()))
        let score = try JohnnySonic.Exporter().convert(work)

        let notes = score.commands.compactMap { command -> DKMPitchesNote? in
            guard case let .pitchesNote(note) = command
            else { return nil }

            return note
        }

        #expect(notes.count == 1)
        #expect(notes[0].location == -0.5)
    }

    @Test
    func convert_standardBeatWork_throws() {
        let work = Work(name: "Test",
                        content: .standardBeat([] as [Part<BeatTime, Pitch>],
                                               TempoMap()))

        #expect(throws: (any Error).self) {
            try JohnnySonic.Exporter().convert(work)
        }
    }

    @Test
    func convert_tempoMap_trailingSegment_isEmitted() throws {
        var tempoMap = TempoMap()

        tempoMap.insert(beatTime: BeatTime(0), tempo: Tempo(120))
        tempoMap.insert(beatTime: BeatTime(4), tempo: Tempo(140))

        var table = NoteTable<BeatTime, NoteNumber>()

        // Extend the work's beatTimeRange past the last tempo entry so
        // there is a trailing segment to emit.
        table.insert(attack: BeatTime(8), duration: BeatDuration(1), pitch: NoteNumber(60))

        let part = Part(name: "Piano", noteTable: table)
        let work = Work(name: "Test", content: .keyboardBeat([part], tempoMap))
        let score = try JohnnySonic.Exporter().convert(work)

        let tempoLines = score.commands.compactMap { command -> DKMTempoLine? in
            guard case let .tempoLine(line) = command
            else { return nil }

            return line
        }

        // One segment from beat 0 to 4, plus a trailing segment from
        // beat 4 through the end of the work — the fix under test.
        #expect(tempoLines.count == 2)

        let trailingSegment = try #require(tempoLines.last)

        #expect(trailingSegment.startBeat == 4.0)
        #expect(trailingSegment.startTempo == 140.0)
        #expect(trailingSegment.endTempo == 140.0)
    }

    @Test
    func convert_unsupportedTimeBasis_throws() {
        let work = Work(name: "Test",
                        content: .keyboardWall([]))

        #expect(throws: (any Error).self) {
            try JohnnySonic.Exporter().convert(work)
        }
    }

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
    func roundTrip_info_preservesWork() throws {
        var table = NoteTable<BeatTime, NoteNumber>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: NoteNumber(60))

        let info = Work.Info(title: "Aubade",
                             subtitles: ["Dawn Song"],
                             alternateTitles: ["Morning Piece"],
                             parentWorkTitle: "Collected Pieces",
                             dedication: "To my teacher\n\nwith thanks",
                             credits: [Credit(name: "J. Smith", role: .composer),
                                       Credit(name: "Anon.")].compactMap(\.self),
                             rights: [RightsNotice(text: "© 1998 Acme\nLine two", scope: .music)].compactMap(\.self),
                             remarks: [Remark(text: "A plain remark"),
                                       Remark(text: "First\n\nSecond", label: "history")].compactMap(\.self))
        let work = Work(name: "Sketch",
                        content: .keyboardBeat([Part(name: "Piano", noteTable: table)], TempoMap()),
                        info: info)
        let recovered = try roundTrip(work,
                                      exporter: JohnnySonic.Exporter(),
                                      importer: JohnnySonic.Importer(),
                                      fileFormat: .dkm)

        #expect(recovered.name == "Sketch")
        #expect(recovered.info == info)
    }

    @Test
    func roundTrip_instrumentChanges_splitNotesIntoSeparateParts() throws {
        var table = NoteTable<BeatTime, NoteNumber>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: NoteNumber(60))
        table.insert(attack: BeatTime(1), duration: BeatDuration(1), pitch: NoteNumber(64))

        var instrumentTable = InstrumentTable<BeatTime>()

        try instrumentTable.insert(time: BeatTime(0), instrument: #require(Instrument(stringValue: "Piano")))
        try instrumentTable.insert(time: BeatTime(1), instrument: #require(Instrument(stringValue: "Flute")))

        let part = Part(name: "Lead", noteTable: table, instrumentTable: instrumentTable)
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

        var instrumentTable1 = InstrumentTable<BeatTime>()

        try instrumentTable1.insert(time: BeatTime(0), instrument: #require(Instrument(stringValue: "Piano")))

        var table2 = NoteTable<BeatTime, NoteNumber>()

        table2.insert(attack: BeatTime(0), duration: BeatDuration(2), pitch: NoteNumber(67))

        var instrumentTable2 = InstrumentTable<BeatTime>()

        try instrumentTable2.insert(time: BeatTime(0), instrument: #require(Instrument(stringValue: "Flute")))

        // Distinct instruments are load-bearing here: the importer groups
        // notes into parts by instrument (see
        // `roundTrip_instrumentChanges_splitNotesIntoSeparateParts`), so two
        // parts sharing the default instrument would collapse into one on
        // the way back in.
        let parts = [Part(name: "P1", noteTable: table1, instrumentTable: instrumentTable1),
                     Part(name: "P2", noteTable: table2, instrumentTable: instrumentTable2)]
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

        panMap.insert(time: BeatTime(0), pan: Pan(horizontal: -45))

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

    // Ramp extras bypass the lossy resample-then-redetect reconstruction
    // `roundTrip_tempo_preservesFlatValue` is limited by: when present on a
    // `TempoMap` entry, the exporter writes the ramp's own anchor values
    // directly into `DKMTempoLine`, and the importer recovers them exactly
    // the same way — the whole point of these three keys.
    @Test
    func roundTrip_tempoRamp_preservesRampExtras() throws {
        var tempoMap = TempoMap()

        tempoMap.insert(beatTime: BeatTime(0),
                        tempo: Tempo(120),
                        extras: Extras(elements: [Extra(name: Extra.rampStartTempo.name, values: [.double(120)]),
                                                  Extra(name: Extra.rampEndTempo.name, values: [.double(160)]),
                                                  Extra(name: Extra.rampDuration.name, values: [.double(4)])]))
        tempoMap.insert(beatTime: BeatTime(4), tempo: Tempo(160))

        var table = NoteTable<BeatTime, NoteNumber>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: NoteNumber(60))

        let part = Part(name: "Piano", noteTable: table)
        let work = Work(name: "TempoRamp", content: .keyboardBeat([part], tempoMap))

        let recovered = try roundTrip(work,
                                      exporter: JohnnySonic.Exporter(),
                                      importer: JohnnySonic.Importer(),
                                      fileFormat: .dkm)
        let recoveredTempoMap = try #require(recovered.tempoMap)

        var foundStart: Double?
        var foundEnd: Double?
        var foundDuration: Double?

        for entry in recoveredTempoMap where entry.beatTime == BeatTime(0) {
            foundStart = doubleValue(entry.extras, .rampStartTempo)
            foundEnd = doubleValue(entry.extras, .rampEndTempo)
            foundDuration = doubleValue(entry.extras, .rampDuration)
        }

        #expect(foundStart == 120)
        #expect(foundEnd == 160)
        #expect(foundDuration == 4)
    }

    @Test
    func writableFileFormats_containsDKM() {
        #expect(JohnnySonic.Exporter().writableFileFormats.contains(.dkm))
    }

    @Test
    func write_emptyWorks_throwsNoWorksToExport() {
        #expect {
            try JohnnySonic.Exporter().write(works: [], as: .dkm)
        } throws: { error in
            guard let jsError = error as? JohnnySonic.Error
            else { return false }

            if case .noWorksToExport = jsError {
                return true
            }
            return false
        }
    }

    @Test
    func write_multipleWorks_throws() {
        let works = [Work(name: "A", content: .keyboardBeat([], TempoMap())),
                     Work(name: "B", content: .keyboardBeat([], TempoMap()))]

        #expect(throws: (any Error).self) {
            try JohnnySonic.Exporter().write(works: works, as: .dkm)
        }
    }

    @Test
    func write_singleKeyboardBeatWork_returnsRegularFile() throws {
        let work = Work(name: "Test",
                        content: .keyboardBeat([], TempoMap()))
        let wrapper = try JohnnySonic.Exporter().write(works: [work],
                                                       as: .dkm)

        #expect(wrapper.isRegularFile)
        #expect(wrapper.regularFileContents?.isEmpty == false)
    }

    @Test
    func write_unsupportedFormat_throws() {
        let work = Work(name: "Test",
                        content: .keyboardBeat([], TempoMap()))

        #expect(throws: (any Error).self) {
            try JohnnySonic.Exporter().write(works: [work],
                                             as: .abc)
        }
    }
}
