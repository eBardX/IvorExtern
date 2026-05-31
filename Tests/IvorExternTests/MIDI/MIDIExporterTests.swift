// © 2025–2026 John Gary Pusey (see LICENSE.md)

import Foundation
@testable import IvorExtern
import IvorMIDI
import IvorModel
import IvorTiming
import IvorTuning
import Testing
import XestiNumbers
import XestiTools

struct MIDIExporterTests {
}

// MARK: -

extension MIDIExporterTests {
    @Test
    func convert_keyboardBeat_empty() throws {
        let work = Work(name: "Test",
                        content: .keyboardBeat([],
                                               TempoMap()))
        let sequence = try MIDI.Exporter().convert(work)

        #expect(sequence.format == .format1)
        #expect(sequence.tracks.count == 1)
    }

    @Test
    func convert_keyboardBeat_singleNote() throws {
        var table = NoteTable<BeatTime, NoteNumber>()

        table.insert(attack: BeatTime(0),
                     duration: BeatDuration(1),
                     pitch: NoteNumber(60))

        let part = Part(name: "Piano",
                        noteTable: table)
        let work = Work(name: "Test",
                        content: .keyboardBeat([part],
                                               TempoMap()))
        let sequence = try MIDI.Exporter().convert(work)

        #expect(sequence.tracks.count == 2)

        let partTrack = sequence.tracks[1]
        let midiEvents = partTrack.events.filter {
            if case .midi = $0 {
                return true
            }

            return false
        }

        #expect(midiEvents.count == 2)

        if case let .midi(t0, msg0) = midiEvents[0] {
            #expect(t0.uintValue == 0)
            if case let .noteOn(_, note, vel) = msg0 {
                #expect(note.uintValue == 60)
                #expect(vel.uintValue == 64)
            }
        }

        if case let .midi(t1, _) = midiEvents[1] {
            #expect(t1.uintValue == 480)
        }
    }

    @Test
    func convert_keyboardBeat_tempoMap() throws {
        var tempoMap = TempoMap()

        tempoMap.insert(beatTime: BeatTime(0),
                        tempo: Tempo(120))
        tempoMap.insert(beatTime: BeatTime(4),
                        tempo: Tempo(120))

        let work = Work(name: "Tempo",
                        content: .keyboardBeat([],
                                               tempoMap))
        let sequence = try MIDI.Exporter().convert(work)

        let track0 = sequence.tracks[0]
        let tempoEvents = track0.events.filter {
            if case let .meta(_, msg) = $0,
               case .tempo = msg { return true }
            return false
        }

        #expect(!tempoEvents.isEmpty)
    }

    @Test
    func convert_keyboardBeat_twoParts() throws {
        var table1 = NoteTable<BeatTime, NoteNumber>()

        table1.insert(attack: BeatTime(0),
                      duration: BeatDuration(1),
                      pitch: NoteNumber(60))

        var table2 = NoteTable<BeatTime, NoteNumber>()

        table2.insert(attack: BeatTime(0),
                      duration: BeatDuration(2),
                      pitch: NoteNumber(64))

        let parts = [Part(name: "P1", noteTable: table1),
                     Part(name: "P2", noteTable: table2)]
        let work = Work(name: "TwoParts",
                        content: .keyboardBeat(parts,
                                               TempoMap()))
        let sequence = try MIDI.Exporter().convert(work)

        #expect(sequence.tracks.count == 3)
    }

    @Test
    func convert_track0_hasTimeSignature() throws {
        let work = Work(name: "",
                        content: .keyboardBeat([],
                                               TempoMap()))
        let sequence = try MIDI.Exporter().convert(work)
        let track0 = sequence.tracks[0]
        let tsigEvents = track0.events.filter {
            if case let .meta(_, msg) = $0,
               case .timeSignature = msg { return true }
            return false
        }

        #expect(tsigEvents.count == 1)
    }

    @Test
    func convert_unsupportedContent_throws() {
        let work = Work(name: "Wall",
                        content: .keyboardWall([]))

        #expect(throws: (any Error).self) {
            try MIDI.Exporter().convert(work)
        }
    }

    // MIDI can only represent instantaneous tempo changes; after the first pass, further roundtrips must not alter the TempoMap.
    @Test
    func roundtrip_tempoMap_accelerando_isStableAfterFirstPass() throws {
        var smoothTempoMap = TempoMap()

        smoothTempoMap.insert(beatTime: BeatTime(0), tempo: Tempo(120))
        smoothTempoMap.insert(beatTime: BeatTime(8), tempo: Tempo(160))

        let originalWork = Work(name: "Accel",
                                content: .keyboardBeat([], smoothTempoMap))

        let sequence1 = try MIDI.Exporter().convert(originalWork)
        let work1 = try MIDI.Importer().convert(sequence1)

        let tempoMap1 = try #require(work1.tempoMap)

        var entries1: [(beatTime: BeatTime, tempo: Tempo)] = []

        tempoMap1.forEach { beatTime, tempo, _ in
            entries1.append((beatTime, tempo))
        }

        let sequence2 = try MIDI.Exporter().convert(work1)
        let work2 = try MIDI.Importer().convert(sequence2)

        let tempoMap2 = try #require(work2.tempoMap)

        var entries2: [(beatTime: BeatTime, tempo: Tempo)] = []

        tempoMap2.forEach { beatTime, tempo, _ in
            entries2.append((beatTime, tempo))
        }

        #expect(entries2.count == entries1.count)

        for i in 0..<min(entries1.count, entries2.count) {
            #expect(entries2[i].beatTime == entries1[i].beatTime,
                    "entry \(i) beatTime mismatch on second pass")
            #expect(entries2[i].tempo == entries1[i].tempo,
                    "entry \(i) tempo mismatch on second pass")
        }
    }

    @Test
    func roundtrip_tempoMap_stepChanges_areIdempotent() throws {
        var canonicalTempoMap = TempoMap()

        canonicalTempoMap.insert(beatTime: BeatTime(0), tempo: Tempo(120))
        canonicalTempoMap.insert(beatTime: BeatTime(4), tempo: Tempo(120))
        canonicalTempoMap.insert(beatTime: BeatTime(4), tempo: Tempo(140))
        canonicalTempoMap.insert(beatTime: BeatTime(8), tempo: Tempo(140))
        canonicalTempoMap.insert(beatTime: BeatTime(8), tempo: Tempo(160))

        let originalWork = Work(name: "Roundtrip",
                                content: .keyboardBeat([], canonicalTempoMap))

        var originalEntries: [(beatTime: BeatTime, tempo: Tempo)] = []

        canonicalTempoMap.forEach { beatTime, tempo, _ in
            originalEntries.append((beatTime, tempo))
        }

        let sequence = try MIDI.Exporter().convert(originalWork)
        let recoveredWork = try MIDI.Importer().convert(sequence)

        let recoveredTempoMap = try #require(recoveredWork.tempoMap)

        var recoveredEntries: [(beatTime: BeatTime, tempo: Tempo)] = []

        recoveredTempoMap.forEach { beatTime, tempo, _ in
            recoveredEntries.append((beatTime, tempo))
        }

        #expect(recoveredEntries.count == originalEntries.count)

        for i in 0..<min(originalEntries.count, recoveredEntries.count) {
            #expect(recoveredEntries[i].beatTime == originalEntries[i].beatTime,
                    "entry \(i) beatTime mismatch")
            #expect(recoveredEntries[i].tempo == originalEntries[i].tempo,
                    "entry \(i) tempo mismatch")
        }
    }

    @Test
    func writableFileFormats_containsMIDI() {
        #expect(MIDI.Exporter().writableFileFormats.contains(.midi))
    }

    @Test
    func write_multipleWorks_throws() {
        let works = [Work(name: "A", content: .keyboardBeat([], TempoMap())),
                     Work(name: "B", content: .keyboardBeat([], TempoMap()))]

        #expect(throws: (any Error).self) {
            try MIDI.Exporter().write(works: works, as: .midi)
        }
    }

    @Test
    func write_singleWork_returnsRegularFile() throws {
        let work = Work(name: "Test", content: .keyboardBeat([], TempoMap()))
        let wrapper = try MIDI.Exporter().write(works: [work], as: .midi)

        #expect(wrapper.isRegularFile)
        #expect(wrapper.regularFileContents?.isEmpty == false)
    }

    @Test
    func write_unsupportedFormat_throws() {
        let work = Work(name: "Test", content: .keyboardBeat([], TempoMap()))

        #expect(throws: (any Error).self) {
            try MIDI.Exporter().write(works: [work], as: .abc)
        }
    }
}
