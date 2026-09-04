// © 2025–2026 John Gary Pusey (see LICENSE.md)

import Foundation
@testable import IvorExtern
import IvorJohnnySonic
import IvorModel
import IvorTiming
import IvorTuning
import Testing
import XestiNumbers
import XestiTools

struct JohnnySonicImporterTests {
}

// MARK: -

extension JohnnySonicImporterTests {
    @Test
    func convert_absoluteBeatWork_stopsAtEnd() throws {
        let before = DKMPitchesNote(startBeat: 0,
                                    duration: 1,
                                    volume: 1,
                                    location: 0,
                                    startPitch: -440,
                                    endPitch: -440,
                                    instrument: "Piano")
        let after = DKMPitchesNote(startBeat: 4,
                                   duration: 1,
                                   volume: 1,
                                   location: 0,
                                   startPitch: -880,
                                   endPitch: -880,
                                   instrument: "Piano")
        let score = JohnnySonic.Score(commands: [.pitchesNote(before), .end, .pitchesNote(after)])
        let work = try JohnnySonic.Importer().convert(score)

        guard case let .absoluteBeat(parts, _) = work.content
        else { Issue.record("Expected absoluteBeat content"); return }

        var attacks: [BeatTime] = []

        parts[0].noteTable.forEach { _, attack, _, _, _, _ in attacks.append(attack) }

        #expect(attacks == [BeatTime(0)])
    }

    @Test
    func convert_keyboardBeatWork_instrumentMapHasOneEntryPerNote() throws {
        let first = DKMPitchesNote(startBeat: 2,
                                   duration: 1,
                                   volume: 1,
                                   location: 0,
                                   startPitch: 60,
                                   endPitch: 60,
                                   instrument: "Piano")
        let second = DKMPitchesNote(startBeat: 5,
                                    duration: 1,
                                    volume: 1,
                                    location: 0,
                                    startPitch: 62,
                                    endPitch: 62,
                                    instrument: "Piano")
        let score = JohnnySonic.Score(commands: [.pitchesNote(first), .pitchesNote(second), .end])
        let work = try JohnnySonic.Importer().convert(score)

        guard case let .keyboardBeat(parts, _) = work.content
        else { Issue.record("Expected keyboardBeat content"); return }

        // Every `/Pitches` line has its own instrument, read off at its own
        // start beat — this reads it per note rather than assuming the
        // first note's instrument speaks for the whole part.
        var entries: [(beatTime: BeatTime, instrument: Instrument)] = []

        parts.first?.instrumentMap.forEach { _, time, instrument, _ in entries.append((time, instrument)) }

        #expect(entries.map(\.beatTime) == [convertToBeatTime(2), convertToBeatTime(5)])
        #expect(entries.allSatisfy { $0.instrument == Instrument("Piano") })
    }

    @Test
    func convert_keyboardBeatWork_populatesInstrumentMap() throws {
        let note = DKMPitchesNote(startBeat: 0,
                                  duration: 1,
                                  volume: 1,
                                  location: 0,
                                  startPitch: 60,
                                  endPitch: 60,
                                  instrument: "Piano")
        let score = JohnnySonic.Score(commands: [.pitchesNote(note), .end])
        let work = try JohnnySonic.Importer().convert(score)

        guard case let .keyboardBeat(parts, _) = work.content
        else { Issue.record("Expected keyboardBeat content"); return }

        #expect(parts[0].instrumentMap[.zero] == Instrument("Piano"))
    }

    @Test
    func convert_keyboardBeatWork_stopsAtEnd() throws {
        let before = DKMPitchesNote(startBeat: 0,
                                    duration: 1,
                                    volume: 1,
                                    location: 0,
                                    startPitch: 60,
                                    endPitch: 60,
                                    instrument: "Piano")
        let after = DKMPitchesNote(startBeat: 4,
                                   duration: 1,
                                   volume: 1,
                                   location: 0,
                                   startPitch: 62,
                                   endPitch: 62,
                                   instrument: "Piano")
        let score = JohnnySonic.Score(commands: [.pitchesNote(before), .end, .pitchesNote(after)])
        let work = try JohnnySonic.Importer().convert(score)

        guard case let .keyboardBeat(parts, _) = work.content
        else { Issue.record("Expected keyboardBeat content"); return }

        var attacks: [BeatTime] = []

        parts[0].noteTable.forEach { _, attack, _, _, _, _ in attacks.append(attack) }

        #expect(attacks == [BeatTime(0)])
    }

    @Test
    func convert_nonContiguousTempoLines_holdsTempoAcrossGap() throws {
        let note = DKMPitchesNote(startBeat: 0,
                                  duration: 1,
                                  volume: 1,
                                  location: 0,
                                  startPitch: 60,
                                  endPitch: 60,
                                  instrument: "Piano")
        let first = DKMTempoLine(startBeat: 0, duration: 4, initialTempo: 60, finalTempo: 100)
        let second = DKMTempoLine(startBeat: 8, duration: 1, initialTempo: 200, finalTempo: 200)
        let score = JohnnySonic.Score(commands: [.pitchesNote(note), .tempoLine(first), .tempoLine(second), .end])
        let work = try JohnnySonic.Importer().convert(score)

        guard case let .keyboardBeat(_, tempoMap) = work.content
        else { Issue.record("Expected keyboardBeat content"); return }

        //
        // `first` leaves its trailing (one-beat-past-the-ramp) sample —
        // 105 BPM, per the reference's own overshoot at that boundary — in
        // effect through the gap (beats 4–7), since nothing overwrites it
        // until `second` begins at beat 8.
        //
        #expect(tempoMap[BeatTime(6)] == Tempo(uintValue: 105))
        #expect(tempoMap[BeatTime(8)] == Tempo(uintValue: 200))
        #expect(tempoMap[BeatTime(9)] == Tempo(uintValue: 200))
    }

    @Test
    func convert_tempoAfterEnd_isIgnored() throws {
        let note = DKMPitchesNote(startBeat: 0,
                                  duration: 1,
                                  volume: 1,
                                  location: 0,
                                  startPitch: 60,
                                  endPitch: 60,
                                  instrument: "Piano")
        let tempo = DKMTempoLine(startBeat: 4, duration: 4, initialTempo: 120, finalTempo: 120)
        let score = JohnnySonic.Score(commands: [.pitchesNote(note), .end, .tempoLine(tempo)])
        let work = try JohnnySonic.Importer().convert(score)

        guard case let .keyboardBeat(_, tempoMap) = work.content
        else { Issue.record("Expected keyboardBeat content"); return }

        #expect(tempoMap.isEmpty)
    }

    @Test
    func convert_tempoLine_populatesTempoMap() throws {
        let note = DKMPitchesNote(startBeat: 0,
                                  duration: 1,
                                  volume: 1,
                                  location: 0,
                                  startPitch: 60,
                                  endPitch: 60,
                                  instrument: "Piano")
        let tempo = DKMTempoLine(startBeat: 0, duration: 4, initialTempo: 120, finalTempo: 120)
        let score = JohnnySonic.Score(commands: [.pitchesNote(note), .tempoLine(tempo), .end])
        let work = try JohnnySonic.Importer().convert(score)

        guard case let .keyboardBeat(_, tempoMap) = work.content
        else { Issue.record("Expected keyboardBeat content"); return }

        #expect(!tempoMap.isEmpty)
    }

    @Test
    func convert_tempoLine_stepsPerBeat_ratherThanRampingContinuously() throws {
        let note = DKMPitchesNote(startBeat: 0,
                                  duration: 1,
                                  volume: 1,
                                  location: 0,
                                  startPitch: 60,
                                  endPitch: 60,
                                  instrument: "Piano")
        //
        // Beats 0–3 each hold a constant midpoint-sampled average BPM —
        // 65, 75, 85, 95 — matching the reference JohnnySonic player's
        // per-beat step behavior, not a value that continuously ramps from
        // 60 toward 100.
        //
        let ramp = DKMTempoLine(startBeat: 0, duration: 4, initialTempo: 60, finalTempo: 100)
        let score = JohnnySonic.Score(commands: [.pitchesNote(note), .tempoLine(ramp), .end])
        let work = try JohnnySonic.Importer().convert(score)

        guard case let .keyboardBeat(_, tempoMap) = work.content
        else { Issue.record("Expected keyboardBeat content"); return }

        #expect(tempoMap[convertToBeatTime(0.5)] == Tempo(uintValue: 65))
        #expect(tempoMap[BeatTime(1)] == Tempo(uintValue: 75))
        #expect(tempoMap[convertToBeatTime(2.9)] == Tempo(uintValue: 85))
        #expect(tempoMap[BeatTime(3)] == Tempo(uintValue: 95))
    }

    @Test
    func read_absoluteBeatWork_roundTrip() throws {
        var noteTable = NoteTable<BeatTime, Frequency>()

        noteTable.insert(attack: BeatTime(0),
                         duration: BeatDuration(2),
                         pitch: Frequency(440))

        let part = Part(name: "", noteTable: noteTable)
        let work = Work(name: "",
                        content: .absoluteBeat([part], TempoMap()))
        let written = try JohnnySonic.Exporter().write(works: [work],
                                                       as: .dkm)
        let read = try JohnnySonic.Importer().read(from: written,
                                                   as: .dkm)

        #expect(read.count == 1)

        if case let .absoluteBeat(parts, _) = read[0].content {
            #expect(parts.count == 1)
            #expect(!parts[0].noteTable.isEmpty)
        } else {
            Issue.record("Expected absoluteBeat content")
        }
    }

    @Test
    func read_emptyData_returnsWork() throws {
        let wrapper = FileWrapper(regularFileWithContents: Data())
        let works = try JohnnySonic.Importer().read(from: wrapper,
                                                    as: .dkm)

        #expect(works.count == 1)
    }

    @Test
    func read_invalidUTF8Data_throws() {
        let wrapper = FileWrapper(regularFileWithContents: Data([0xff, 0xfe, 0x00]))

        #expect(throws: (any Error).self) {
            try JohnnySonic.Importer().read(from: wrapper,
                                            as: .dkm)
        }
    }

    @Test
    func read_keyboardBeatWork_roundTrip() throws {
        var noteTable = NoteTable<BeatTime, NoteNumber>()

        noteTable.insert(attack: BeatTime(0),
                         duration: BeatDuration(2),
                         pitch: NoteNumber(60))

        let part = Part(name: "", noteTable: noteTable)
        let work = Work(name: "Round Trip",
                        content: .keyboardBeat([part], TempoMap()))
        let written = try JohnnySonic.Exporter().write(works: [work],
                                                       as: .dkm)
        let read = try JohnnySonic.Importer().read(from: written,
                                                   as: .dkm)

        #expect(read.count == 1)
        #expect(read[0].name == "Round Trip")

        if case let .keyboardBeat(parts, _) = read[0].content {
            #expect(parts.count == 1)
            #expect(!parts[0].noteTable.isEmpty)
        } else {
            Issue.record("Expected keyboardBeat content")
        }
    }

    @Test
    func read_keyboardBeatWork_roundTrip_preservesDynamic() throws {
        var noteTable = NoteTable<BeatTime, NoteNumber>()

        noteTable.insert(attack: BeatTime(0),
                         duration: BeatDuration(1),
                         pitch: NoteNumber(60))

        var dynamicMap = DynamicMap<BeatTime>()

        dynamicMap.insert(time: BeatTime(0),
                          dynamic: .mp)

        let part = Part(name: "", noteTable: noteTable, dynamicMap: dynamicMap)
        let work = Work(name: "", content: .keyboardBeat([part], TempoMap()))
        let written = try JohnnySonic.Exporter().write(works: [work],
                                                       as: .dkm)
        let read = try JohnnySonic.Importer().read(from: written,
                                                   as: .dkm)

        if case let .keyboardBeat(parts, _) = read[0].content {
            #expect(parts[0].dynamicMap[BeatTime(0)] == .mp)
        } else {
            Issue.record("Expected keyboardBeat content")
        }
    }

    @Test
    func read_keyboardBeatWork_roundTrip_preservesPan() throws {
        var noteTable = NoteTable<BeatTime, NoteNumber>()

        noteTable.insert(attack: BeatTime(0),
                         duration: BeatDuration(1),
                         pitch: NoteNumber(60))

        var panMap = PanMap<BeatTime>()

        panMap.insert(time: BeatTime(0), pan: Pan(0.5))

        let part = Part(name: "",
                        noteTable: noteTable,
                        panMap: panMap)
        let work = Work(name: "",
                        content: .keyboardBeat([part], TempoMap()))
        let written = try JohnnySonic.Exporter().write(works: [work],
                                                       as: .dkm)
        let read = try JohnnySonic.Importer().read(from: written,
                                                   as: .dkm)

        if case let .keyboardBeat(parts, _) = read[0].content {
            #expect(parts[0].panMap[BeatTime(0)] == Pan(0.5))
        } else {
            Issue.record("Expected keyboardBeat content")
        }
    }

    @Test
    func read_unsupportedFormat_throws() {
        let wrapper = FileWrapper(regularFileWithContents: Data())

        #expect(throws: (any Error).self) {
            try JohnnySonic.Importer().read(from: wrapper,
                                            as: .abc)
        }
    }

    @Test
    func read_withTempoMap_preservesTempo() throws {
        var tempoMap = TempoMap()

        tempoMap.insert(beatTime: BeatTime(0),
                        tempo: Tempo(120))
        tempoMap.insert(beatTime: BeatTime(8),
                        tempo: Tempo(120))

        let work = Work(name: "",
                        content: .keyboardBeat([], tempoMap))
        let written = try JohnnySonic.Exporter().write(works: [work],
                                                       as: .dkm)
        let read = try JohnnySonic.Importer().read(from: written,
                                                   as: .dkm)

        #expect(read.count == 1)

        if case let .keyboardBeat(_, readTempoMap) = read[0].content {
            #expect(!readTempoMap.isEmpty)
        } else {
            Issue.record("Expected keyboardBeat content")
        }
    }

    @Test
    func readableFileFormats_containsDKM() {
        #expect(JohnnySonic.Importer().readableFileFormats.contains(.dkm))
    }
}
