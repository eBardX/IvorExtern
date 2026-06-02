// © 2025–2026 John Gary Pusey (see LICENSE.md)

import Foundation
@testable import IvorExtern
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
