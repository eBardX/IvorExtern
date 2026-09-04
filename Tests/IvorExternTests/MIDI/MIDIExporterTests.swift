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
    func convert_channelIdentity_duplicateClaim_fallsBackToLowestUnclaimed() throws {
        var table = NoteTable<BeatTime, NoteNumber>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: NoteNumber(60))

        let parts = [Part(name: "Channel 3", noteTable: table),
                     Part(name: "Channel 3", noteTable: table)]
        let work = Work(name: "Dup", content: .keyboardBeat(parts, TempoMap()))
        let sequence = try MIDI.Exporter().convert(work)

        let channels = sequence.tracks[1...].map { track in
            track.events.compactMap { event -> MIDIChannel? in
                guard case let .midi(_, message) = event
                else { return nil }

                return message.channel
            }.first
        }

        #expect(channels[0]?.uintValue == 3)
        #expect(channels[1]?.uintValue == 1)
    }

    @Test
    func convert_channelIdentity_nonContiguousChannels_roundTrips() throws {
        var table = NoteTable<BeatTime, NoteNumber>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: NoteNumber(60))

        let parts = [Part(name: "Channel 1", noteTable: table),
                     Part(name: "Channel 5", noteTable: table),
                     Part(name: "Channel 9", noteTable: table)]
        let work = Work(name: "NonContiguous", content: .keyboardBeat(parts, TempoMap()))

        let sequence = try MIDI.Exporter().convert(work)
        let recovered = try MIDI.Importer().convert(sequence)

        guard case let .keyboardBeat(recoveredParts, _) = recovered.content
        else { Issue.record("Expected keyboardBeat content"); return }

        let recoveredChannels = Set(recoveredParts.map(\.name)).sorted()

        #expect(recoveredChannels == ["Channel 1", "Channel 5", "Channel 9"])
    }

    @Test
    func convert_channelIdentity_renamedPart_fallsBackToLowestUnclaimed() throws {
        var table = NoteTable<BeatTime, NoteNumber>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: NoteNumber(60))

        let parts = [Part(name: "Renamed", noteTable: table),
                     Part(name: "Channel 1", noteTable: table)]
        let work = Work(name: "Renamed", content: .keyboardBeat(parts, TempoMap()))
        let sequence = try MIDI.Exporter().convert(work)

        let channels = sequence.tracks[1...].map { track in
            track.events.compactMap { event -> MIDIChannel? in
                guard case let .midi(_, message) = event
                else { return nil }

                return message.channel
            }.first
        }

        // "Channel 1" claims channel 1, so the unnamed-match part falls
        // back to the lowest unclaimed channel, 2.
        #expect(channels[0]?.uintValue == 2)
        #expect(channels[1]?.uintValue == 1)
    }

    @Test
    func convert_instrumentMap_changesMidPart_emitTwoProgramChanges() throws {
        var table = NoteTable<BeatTime, NoteNumber>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: NoteNumber(60))
        table.insert(attack: BeatTime(1), duration: BeatDuration(1), pitch: NoteNumber(62))

        var instrumentMap = InstrumentMap<BeatTime>()

        try instrumentMap.insert(time: BeatTime(0), instrument: #require(Instrument(stringValue: "Acoustic Grand Piano")))
        try instrumentMap.insert(time: BeatTime(1), instrument: #require(Instrument(stringValue: "Vibraphone")))

        let part = Part(name: "Piano",
                        noteTable: table,
                        instrumentMap: instrumentMap)
        let work = Work(name: "Test", content: .keyboardBeat([part], TempoMap()))
        let sequence = try MIDI.Exporter().convert(work)

        let programChanges = sequence.tracks[1].events.compactMap { event -> MIDI.ProgramNumber? in
            guard case let .midi(_, .programChange(_, program)) = event
            else { return nil }

            return program
        }

        #expect(programChanges == [MIDI.ProgramNumber(0), MIDI.ProgramNumber(11)])
    }

    @Test
    func convert_instrumentMap_present_emitsProgramChange() throws {
        var instrumentMap = InstrumentMap<BeatTime>()

        try instrumentMap.insert(time: BeatTime(0), instrument: #require(Instrument(stringValue: "Vibraphone")))

        let part = Part(name: "Piano",
                        noteTable: NoteTable<BeatTime, NoteNumber>(),
                        instrumentMap: instrumentMap)
        let work = Work(name: "Test", content: .keyboardBeat([part], TempoMap()))
        let sequence = try MIDI.Exporter().convert(work)

        let programChanges = sequence.tracks[1].events.compactMap { event -> MIDI.ProgramNumber? in
            guard case let .midi(_, .programChange(_, program)) = event
            else { return nil }

            return program
        }

        #expect(programChanges == [MIDI.ProgramNumber(11)])
    }

    @Test
    func convert_instrumentMap_unrecognizedName_omitsDirective() throws {
        var instrumentMap = InstrumentMap<BeatTime>()

        try instrumentMap.insert(time: BeatTime(0), instrument: #require(Instrument(stringValue: "Not A Real Instrument")))

        let part = Part(name: "Piano",
                        noteTable: NoteTable<BeatTime, NoteNumber>(),
                        instrumentMap: instrumentMap)
        let work = Work(name: "Test", content: .keyboardBeat([part], TempoMap()))
        let sequence = try MIDI.Exporter().convert(work)

        let hasProgramChange = sequence.tracks[1].events.contains {
            if case .midi(_, .programChange) = $0 {
                return true
            }
            return false
        }

        #expect(!hasProgramChange)
    }

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

        let channels = sequence.tracks[1...].map { track in
            track.events.compactMap { event -> MIDIChannel? in
                guard case let .midi(_, message) = event
                else { return nil }

                return message.channel
            }.first
        }

        #expect(Set(channels.compactMap { $0 }).count == 2)
    }

    @Test
    func convert_sixteenParts_succeeds() throws {
        let parts = (1...16).map {
            Part(name: "P\($0)", noteTable: NoteTable<BeatTime, NoteNumber>())
        }
        let work = Work(name: "Sixteen", content: .keyboardBeat(parts, TempoMap()))
        let sequence = try MIDI.Exporter().convert(work)

        #expect(sequence.tracks.count == 17)
    }

    @Test
    func convert_tooManyParts_throws() {
        let parts = (1...17).map {
            Part(name: "P\($0)",
                 noteTable: NoteTable<BeatTime, NoteNumber>())
        }
        let work = Work(name: "TooMany",
                        content: .keyboardBeat(parts,
                                               TempoMap()))

        #expect(throws: (any Error).self) {
            try MIDI.Exporter().convert(work)
        }
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
    func roundtrip_dynamicRamp_survivesExportReimport() throws {
        var table = NoteTable<BeatTime, NoteNumber>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(4), pitch: NoteNumber(60))

        var dynamicMap = DynamicMap<BeatTime>()

        try dynamicMap.insert(time: BeatTime(0), dynamic: #require(Dynamic(numberValue: Number(0.2))))
        try dynamicMap.insert(time: BeatTime(4), dynamic: #require(Dynamic(numberValue: Number(0.9))))

        let part = Part(name: "Piano", noteTable: table, dynamicMap: dynamicMap)
        let work = Work(name: "Ramp", content: .keyboardBeat([part], TempoMap()))

        let sequence = try MIDI.Exporter().convert(work)
        let recovered = try MIDI.Importer().convert(sequence)

        guard case let .keyboardBeat(parts, _) = recovered.content,
              let recoveredPart = parts.first
        else { Issue.record("Expected a recovered part"); return }

        #expect(recoveredPart.noteTable.timeRange != nil)
    }

    @Test
    func roundtrip_panRamp_survivesExportReimport() throws {
        var panMap = PanMap<BeatTime>()

        try panMap.insert(time: BeatTime(0), pan: #require(Pan(numberValue: Number(-1.0))))
        try panMap.insert(time: BeatTime(4), pan: #require(Pan(numberValue: Number(1.0))))

        let part = Part(name: "Piano",
                        noteTable: NoteTable<BeatTime, NoteNumber>(),
                        panMap: panMap)
        let work = Work(name: "PanRamp", content: .keyboardBeat([part], TempoMap()))

        let sequence = try MIDI.Exporter().convert(work)
        let recovered = try MIDI.Importer().convert(sequence)

        guard case let .keyboardBeat(parts, _) = recovered.content,
              let recoveredPart = parts.first
        else { Issue.record("Expected a recovered part"); return }

        #expect(!recoveredPart.panMap.isEmpty)
    }

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

        tempoMap1.forEach { _, beatTime, tempo, _ in
            entries1.append((beatTime, tempo))
        }

        let sequence2 = try MIDI.Exporter().convert(work1)
        let work2 = try MIDI.Importer().convert(sequence2)

        let tempoMap2 = try #require(work2.tempoMap)

        var entries2: [(beatTime: BeatTime, tempo: Tempo)] = []

        tempoMap2.forEach { _, beatTime, tempo, _ in
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

        canonicalTempoMap.forEach { _, beatTime, tempo, _ in
            originalEntries.append((beatTime, tempo))
        }

        let sequence = try MIDI.Exporter().convert(originalWork)
        let recoveredWork = try MIDI.Importer().convert(sequence)

        let recoveredTempoMap = try #require(recoveredWork.tempoMap)

        var recoveredEntries: [(beatTime: BeatTime, tempo: Tempo)] = []

        recoveredTempoMap.forEach { _, beatTime, tempo, _ in
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
    func write_emptyWorks_throwsNoWorksToExport() {
        #expect {
            try MIDI.Exporter().write(works: [], as: .midi)
        } throws: { error in
            guard let midiError = error as? MIDI.Error
            else { return false }

            if case .noWorksToExport = midiError {
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
