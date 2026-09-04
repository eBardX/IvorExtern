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

        var instrumentMap = InstrumentMap<BeatTime>()

        try instrumentMap.insert(time: BeatTime(0), instrument: #require(Instrument(stringValue: "Flute")))

        let part = Part(name: "Piano", noteTable: table, instrumentMap: instrumentMap)
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
    func convert_pan_emittedOnNote() throws {
        var table = NoteTable<BeatTime, NoteNumber>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: NoteNumber(60))

        var panMap = PanMap<BeatTime>()

        try panMap.insert(time: BeatTime(0), pan: #require(Pan(numberValue: Number(-0.5))))

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
        #expect(trailingSegment.initialTempo == 140.0)
        #expect(trailingSegment.finalTempo == 140.0)
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
