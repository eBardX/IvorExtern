// © 2026 John Gary Pusey (see LICENSE.md)

import IvorExtern
import IvorMIDI
import IvorModel
import IvorTiming
import IvorTuning
import Testing
import XestiTools

struct WorkPerformanceTests {
}

// MARK: -

extension WorkPerformanceTests {
    @Test
    func channelOutputs_channelGoesWhereItsFirstPartGoes() throws {
        let performance = try #require(WorkPerformance(work: Self.keyboardWallWork(Array(repeating: [(0, 1, 60)],
                                                                                         count: 16))))
        let outputs = performance.channelOutputs(forPartOutputs: Array(1...16))

        #expect(performance.partChannels.map(\.uintValue) == [1, 2, 3, 4, 5, 6, 7, 8, 9, 11, 12, 13, 14, 15, 16, 1])
        #expect(outputs == [1, 2, 3, 4, 5, 6, 7, 8, 9, nil, 10, 11, 12, 13, 14, 15])
    }

    @Test
    func channelOutputs_partOnSeveralChannels_takesThemAll() throws {
        let part = Self.twoInstrumentPart()
        let vanilla = try Self.assignment(.generalMIDI1(program: 20),
                                          channel: 3)
        let chocolate = try Self.assignment(.generalMIDI1(program: 41),
                                            channel: 4)
        let realization = Realization(partTables: [part.partID: PatchTable([.vanilla: vanilla,
                                                                            Self.chocolate: chocolate])])
        let performance = try #require(WorkPerformance(work: Work(content: .keyboardWall([part])),
                                                       realization: realization))
        let outputs = performance.channelOutputs(forPartOutputs: ["Synth"])

        #expect(performance.partChannelSets.map { $0.map(\.uintValue) } == [[3, 4]])
        #expect(outputs.enumerated().compactMap { $1 == nil ? nil : $0 + 1 } == [3, 4])
    }

    @Test
    func events_assignment_overridesGeneralMIDIName() throws {
        let part = Part<WallTime, NoteNumber>(name: "Part 1")
        let realization = try Realization(defaults: PatchTable([part.instrumentMap[.zero]: Self.assignment(.generalMIDI1(program: 20))]))
        let performance = try #require(WorkPerformance(work: Work(content: .keyboardWall([part])),
                                                       realization: realization))

        #expect(performance.events.map(\.message) == [.programChange(1, 20)])
    }

    @Test
    func events_assignmentChannels_sendEveryPatchAtStart() throws {
        let part = Self.twoInstrumentPart()
        let vanilla = try Self.assignment(.generalMIDI1(program: 20),
                                          channel: 3)
        let chocolate = try Self.assignment(.generalMIDI1(program: 41),
                                            channel: 4)
        let realization = Realization(partTables: [part.partID: PatchTable([.vanilla: vanilla,
                                                                            Self.chocolate: chocolate])])
        let performance = try #require(WorkPerformance(work: Work(content: .keyboardWall([part])),
                                                       realization: realization))
        let programs = performance.events.filter {
            if case .programChange = $0.message { true } else { false }
        }
        let noteOns = performance.events.compactMap { event -> UInt? in
            guard case .noteOn = event.message
            else { return nil }

            return event.message.channel.uintValue
        }

        #expect(Set(programs.map(\.time)) == [.zero])
        #expect(Set(programs.map(\.message)) == [.programChange(3, 20), .programChange(4, 41)])
        #expect(noteOns == [3, 4])
    }

    @Test
    func events_backToBackNotes_releaseBeforeRetriggering() throws {
        let performance = try #require(WorkPerformance(work: Self.keyboardWallWork([[(0, 1, 60), (1, 1, 60)]])))
        let atOne = performance.events.filter { $0.time == Self.wallTime(1) }.map(\.message)

        #expect(atOne == [.noteOff(1, 60, 0), .noteOn(1, 60, 100)])
    }

    //
    // 29.381986 + 1.304348 in seconds is a hair over 30.686334, but the release is exact.
    //
    @Test
    func events_backToBackNotes_releaseBeforeRetriggeringDespiteRounding() throws {
        let performance = try #require(WorkPerformance(work: Self.keyboardWallWork([[(29.381986, 1.304348, 78),
                                                                                     (30.686334, 0.652174, 78)]])))
        let notes = performance.events.map(\.message).filter {
            if case .programChange = $0 { false } else { true }
        }

        #expect(notes == [.noteOn(1, 78, 100),
                          .noteOff(1, 78, 0),
                          .noteOn(1, 78, 100),
                          .noteOff(1, 78, 0)])
    }

    @Test
    func events_customBank_splitsIntoMSBAndLSB() throws {
        let part = Part<WallTime, NoteNumber>(name: "Part 1")
        let assignment = try Self.assignment(.custom(program: 5,
                                                     bank: 15_489,
                                                     name: nil))
        let realization = Realization(defaults: PatchTable([part.instrumentMap[.zero]: assignment]))
        let performance = try #require(WorkPerformance(work: Work(content: .keyboardWall([part])),
                                                       realization: realization))
        let expected: [MIDIChannelMessage] = [.controlChange(1, .bankSelectMSB, 121),
                                              .controlChange(1, .bankSelectLSB, 1),
                                              .programChange(1, 5)]

        #expect(performance.events.map(\.message) == expected)
    }

    @Test
    func events_eachPartOnItsOwnChannel_skippingPercussion() throws {
        let performance = try #require(WorkPerformance(work: Self.keyboardWallWork(Array(repeating: [(0, 1, 60)],
                                                                                         count: 16))))
        let channels = performance.events.compactMap { event -> UInt? in
            guard case .noteOn = event.message
            else { return nil }

            return event.message.channel.uintValue
        }

        #expect(channels == [1, 2, 3, 4, 5, 6, 7, 8, 9, 11, 12, 13, 14, 15, 16, 1])
    }

    @Test
    func events_generalMIDI1AfterBank_resetsBank() throws {
        let part = Self.twoInstrumentPart()
        let vanilla = try Self.assignment(.generalMIDI2(program: 20,
                                                        variation: 1))
        let chocolate = try Self.assignment(.generalMIDI1(program: 41))
        let realization = Realization(partTables: [part.partID: PatchTable([.vanilla: vanilla,
                                                                            Self.chocolate: chocolate])])
        let performance = try #require(WorkPerformance(work: Work(content: .keyboardWall([part])),
                                                       realization: realization))
        let atTwo = performance.events.filter { $0.time == Self.wallTime(2) }.map(\.message)

        #expect(atTwo == [.controlChange(1, .bankSelectMSB, 0),
                          .controlChange(1, .bankSelectLSB, 0),
                          .programChange(1, 41)])
    }

    @Test
    func events_generalMIDI2_sendsBankBeforeProgram() throws {
        let part = Part<WallTime, NoteNumber>(name: "Part 1")
        let realization = try Realization(defaults: PatchTable([part.instrumentMap[.zero]: Self.assignment(.generalMIDI2(program: 20,
                                                                                                                         variation: 1))]))
        let performance = try #require(WorkPerformance(work: Work(content: .keyboardWall([part])),
                                                       realization: realization))

        #expect(performance.events.map(\.message) == [.controlChange(1, .bankSelectMSB, 121),
                                                      .controlChange(1, .bankSelectLSB, 1),
                                                      .programChange(1, 20)])
    }

    @Test
    func events_instrument_picksGeneralMIDIProgram() throws {
        var instrumentMap = InstrumentMap<WallTime>()

        try instrumentMap.insert(time: .zero,
                                 instrument: #require(Instrument(stringValue: "Violin")))
        try instrumentMap.insert(time: Self.wallTime(2),
                                 instrument: #require(Instrument(stringValue: "Not a GM Name")))

        let part = Part<WallTime, NoteNumber>(name: "Part 1",
                                              instrumentMap: instrumentMap)
        let performance = try #require(WorkPerformance(work: Work(content: .keyboardWall([part]))))
        let programs = performance.events.filter {
            if case .programChange = $0.message { true } else { false }
        }

        //
        // A name General MIDI doesn't know falls back to its first program, a piano.
        //
        #expect(programs == [WorkPerformance.Event(time: Self.wallTime(0), message: .programChange(1, 41)),
                             WorkPerformance.Event(time: Self.wallTime(2), message: .programChange(1, 1))])
    }

    @Test
    func events_percussion_playsOnChannel10() throws {
        let work = Self.keyboardWallWork([[(0, 1, 36)]])
        let part = try #require(work.part(work.partIDs[0], as: Part<WallTime, NoteNumber>.self))
        let realization = try Realization(defaults: PatchTable([part.instrumentMap[.zero]: Self.assignment(.generalMIDI1Percussion)]))
        let performance = try #require(WorkPerformance(work: work,
                                                       realization: realization))

        #expect(performance.events.map(\.message.channel.uintValue) == [10, 10, 10])
        #expect(performance.partChannelSets.map { $0.map(\.uintValue) } == [[10]])
    }

    @Test
    func init_keyboardWallWork_sortsNotesByTime() throws {
        let performance = try #require(WorkPerformance(work: Self.keyboardWallWork([[(1, 0.5, 62)],
                                                                                    [(0, 2, 50)]])))
        let notes = performance.events.filter {
            if case .programChange = $0.message { false } else { true }
        }

        #expect(performance.duration == Self.wallTime(2))
        #expect(notes == [WorkPerformance.Event(time: Self.wallTime(0), message: .noteOn(2, 50, 100)),
                          WorkPerformance.Event(time: Self.wallTime(1), message: .noteOn(1, 62, 100)),
                          WorkPerformance.Event(time: Self.wallTime(1.5), message: .noteOff(1, 62, 0)),
                          WorkPerformance.Event(time: Self.wallTime(2), message: .noteOff(2, 50, 0))])
    }

    @Test
    func init_otherWork_isNil() {
        #expect(WorkPerformance(work: Work(content: .standardBeat([], TempoMap()))) == nil)
        #expect(WorkPerformance(work: Work(content: .keyboardBeat([], TempoMap()))) == nil)
    }

    @Test
    func event_sameTime_ordersOffsBanksProgramsOns() {
        let time = Self.wallTime(1)
        let ordered: [MIDIChannelMessage] = [.noteOff(1, 60, 0),
                                             .controlChange(1, .bankSelectMSB, 121),
                                             .controlChange(1, .bankSelectLSB, 1),
                                             .programChange(1, 20),
                                             .controlChange(1, .sustain, 0),
                                             .noteOn(1, 60, 100)]
        let events = ordered.reversed().map { WorkPerformance.Event(time: time, message: $0) }

        #expect(events.sorted().map(\.message) == ordered)
        #expect(WorkPerformance.Event(time: .zero, message: .noteOn(1, 60, 100))
            < WorkPerformance.Event(time: time, message: .noteOff(1, 60, 0)))
    }

    // MARK: Private Type Properties

    private static let chocolate: Instrument = "Chocolate"

    // MARK: Private Type Methods

    private static func assignment(_ kind: Patch.Kind,
                                   channel: Int? = nil) throws -> PatchTable.Assignment {
        let patch = try #require(Patch(kind))

        return try #require(PatchTable.Assignment(patch: patch,
                                                  channel: channel))
    }

    //
    // Each part is a list of notes as (attack, duration, key), in seconds.
    //
    private static func keyboardWallWork(_ parts: [[(Double, Double, UInt)]]) -> Work {
        let parts = parts.enumerated().map { offset, notes in
            var noteTable = NoteTable<WallTime, NoteNumber>()

            for (attack, duration, key) in notes {
                noteTable.insert(attack: wallTime(attack),
                                 duration: wallDuration(duration),
                                 pitch: noteNumber(key))
            }

            return Part<WallTime, NoteNumber>(name: "Part \(offset + 1)",
                                              noteTable: noteTable)
        }

        return Work(content: .keyboardWall(parts))
    }

    private static func noteNumber(_ uintValue: UInt) -> NoteNumber {
        // swiftlint:disable:next force_unwrapping
        NoteNumber(uintValue: uintValue)!
    }

    //
    // `Vanilla` from the start, with a note at 0, then `Chocolate` from 2, with a note at 3.
    //
    private static func twoInstrumentPart() -> Part<WallTime, NoteNumber> {
        var instrumentMap = InstrumentMap<WallTime>()
        var noteTable = NoteTable<WallTime, NoteNumber>()

        instrumentMap.insert(time: .zero,
                             instrument: .vanilla)
        instrumentMap.insert(time: wallTime(2),
                             instrument: chocolate)

        noteTable.insert(attack: .zero,
                         duration: wallDuration(1),
                         pitch: noteNumber(60))
        noteTable.insert(attack: wallTime(3),
                         duration: wallDuration(1),
                         pitch: noteNumber(62))

        return Part<WallTime, NoteNumber>(name: "Part 1",
                                          noteTable: noteTable,
                                          instrumentMap: instrumentMap)
    }

    private static func wallDuration(_ seconds: Double) -> WallDuration {
        // swiftlint:disable:next force_unwrapping
        WallDuration(uintValue: UInt((seconds * 1_000_000).rounded()))!
    }

    private static func wallTime(_ seconds: Double) -> WallTime {
        // swiftlint:disable:next force_unwrapping
        WallTime(uintValue: UInt((seconds * 1_000_000).rounded()))!
    }
}
