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
        let performance = try #require(WorkPerformance(work: makeKeyboardWallWork(Array(repeating: [(0, 1, 60)],
                                                                                        count: 16))))
        let outputs = performance.channelOutputs(forPartOutputs: Array(1...16))

        #expect(performance.partChannels.map(\.uintValue) == [1, 2, 3, 4, 5, 6, 7, 8, 9, 11, 12, 13, 14, 15, 16, 1])
        #expect(outputs == [1, 2, 3, 4, 5, 6, 7, 8, 9, nil, 10, 11, 12, 13, 14, 15])
    }

    @Test
    func channelOutputs_partOnSeveralChannels_takesThemAll() throws {
        let part = makeTwoInstrumentPart()
        let vanilla = try patchAssignment(.generalMIDI1(program: 20),
                                          channel: 3)
        let chocolate = try patchAssignment(.generalMIDI1(program: 41),
                                            channel: 4)
        let realization = Realization(partTables: [part.partID: PatchTable([.vanilla: vanilla,
                                                                            chocolateInstrument: chocolate])])
        let performance = try #require(WorkPerformance(work: Work(content: .keyboardWall([part])),
                                                       realization: realization))
        let outputs = performance.channelOutputs(forPartOutputs: ["Synth"])

        #expect(performance.partChannelSets.map { $0.map(\.uintValue) } == [[3, 4]])
        #expect(outputs.enumerated().compactMap { $1 == nil ? nil : $0 + 1 } == [3, 4])
    }

    @Test
    func event_sameTime_ordersOffsBanksProgramsPansOns() {
        let time = makeWallTime(1)
        let ordered: [MIDIChannelMessage] = [.noteOff(1, 60, 0),
                                             .controlChange(1, .bankSelectMSB, 121),
                                             .controlChange(1, .bankSelectLSB, 1),
                                             .programChange(1, 20),
                                             .controlChange(1, .panMSB, 64),
                                             .controlChange(1, .panLSB, 8),
                                             .controlChange(1, .sustain, 0),
                                             .noteOn(1, 60, 100)]
        let events = ordered.reversed().map { WorkPerformance.Event(time: time, message: $0) }

        #expect(events.sorted().map(\.message) == ordered)
        #expect(WorkPerformance.Event(time: .zero, message: .noteOn(1, 60, 100))
            < WorkPerformance.Event(time: time, message: .noteOff(1, 60, 0)))
    }

    @Test
    func events_assignment_overridesGeneralMIDIName() throws {
        let part = Part<WallTime, NoteNumber>(name: "Part 1")
        let realization = try Realization(defaults: PatchTable([part.instrumentMap[.zero]: patchAssignment(.generalMIDI1(program: 20))]))
        let performance = try #require(WorkPerformance(work: Work(content: .keyboardWall([part])),
                                                       realization: realization))

        #expect(performance.events.map(\.message) == [.programChange(1, 20),
                                                      .controlChange(1, .panMSB, 64)])
    }

    @Test
    func events_assignmentChannels_sendEveryPatchAtStart() throws {
        let part = makeTwoInstrumentPart()
        let vanilla = try patchAssignment(.generalMIDI1(program: 20),
                                          channel: 3)
        let chocolate = try patchAssignment(.generalMIDI1(program: 41),
                                            channel: 4)
        let realization = Realization(partTables: [part.partID: PatchTable([.vanilla: vanilla,
                                                                            chocolateInstrument: chocolate])])
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
        let performance = try #require(WorkPerformance(work: makeKeyboardWallWork([[(0, 1, 60), (1, 1, 60)]])))
        let atOne = performance.events.filter { $0.time == makeWallTime(1) }.map(\.message)

        #expect(atOne == [.noteOff(1, 60, 0), .noteOn(1, 60, 64)])
    }

    //
    // 29.381986 + 1.304348 in seconds is a hair over 30.686334, but the release is exact.
    //
    @Test
    func events_backToBackNotes_releaseBeforeRetriggeringDespiteRounding() throws {
        let performance = try #require(WorkPerformance(work: makeKeyboardWallWork([[(29.381986, 1.304348, 78),
                                                                                    (30.686334, 0.652174, 78)]])))
        let notes = performance.events.map(\.message).filter(isNoteMessage)

        #expect(notes == [.noteOn(1, 78, 64),
                          .noteOff(1, 78, 0),
                          .noteOn(1, 78, 64),
                          .noteOff(1, 78, 0)])
    }

    @Test
    func events_customBank_splitsIntoMSBAndLSB() throws {
        let part = Part<WallTime, NoteNumber>(name: "Part 1")
        let assignment = try patchAssignment(.custom(program: 5,
                                                     bank: 15_489,
                                                     name: nil))
        let realization = Realization(defaults: PatchTable([part.instrumentMap[.zero]: assignment]))
        let performance = try #require(WorkPerformance(work: Work(content: .keyboardWall([part])),
                                                       realization: realization))
        let expected: [MIDIChannelMessage] = [.controlChange(1, .bankSelectMSB, 121),
                                              .controlChange(1, .bankSelectLSB, 1),
                                              .programChange(1, 5),
                                              .controlChange(1, .panMSB, 64)]

        #expect(performance.events.map(\.message) == expected)
    }

    @Test
    func events_dynamicRamp_risesNoteByNote() throws {
        var part = try #require(makeKeyboardWallParts([[(0, 1, 60), (2, 1, 62), (4, 1, 64)]]).first)

        part.dynamicMap.insert(time: .zero, dynamic: .pp)
        part.dynamicMap.insert(time: makeWallTime(4), dynamic: .ff)

        let performance = try #require(WorkPerformance(work: Work(content: .keyboardWall([part]))))

        //
        // pp is 0.3 and ff 0.8, so halfway is 0.55: 38, 70 and 102 out of 127.
        //
        #expect(noteOnVelocities(performance) == [38, 70, 102])
    }

    @Test
    func events_eachPartOnItsOwnChannel_skippingPercussion() throws {
        let performance = try #require(WorkPerformance(work: makeKeyboardWallWork(Array(repeating: [(0, 1, 60)],
                                                                                        count: 16))))
        let channels = performance.events.compactMap { event -> UInt? in
            guard case .noteOn = event.message
            else { return nil }

            return event.message.channel.uintValue
        }

        #expect(channels == [1, 2, 3, 4, 5, 6, 7, 8, 9, 11, 12, 13, 14, 15, 16, 1])
    }

    @Test
    func events_exactVelocity_winsForItsNote() throws {
        var part = try #require(makeKeyboardWallParts([[(0, 1, 60), (1, 1, 62)]]).first)
        let second = try #require(part.noteTable.first { $0.attack == makeWallTime(1) })

        part.dynamicMap.insert(time: .zero, dynamic: .f)
        part.noteTable.updateExtras(noteID: second.noteID,
                                    extras: Extras(elements: [Extra(name: Extra.attackVelocity.name, values: [.int(77)])]))

        let performance = try #require(WorkPerformance(work: Work(content: .keyboardWall([part]))))

        #expect(noteOnVelocities(performance) == [89, 77])
    }

    @Test
    func events_generalMIDI1AfterBank_resetsBank() throws {
        let part = makeTwoInstrumentPart()
        let vanilla = try patchAssignment(.generalMIDI2(program: 20,
                                                        variation: 1))
        let chocolate = try patchAssignment(.generalMIDI1(program: 41))
        let realization = Realization(partTables: [part.partID: PatchTable([.vanilla: vanilla,
                                                                            chocolateInstrument: chocolate])])
        let performance = try #require(WorkPerformance(work: Work(content: .keyboardWall([part])),
                                                       realization: realization))
        let atTwo = performance.events.filter { $0.time == makeWallTime(2) }.map(\.message)

        #expect(atTwo == [.controlChange(1, .bankSelectMSB, 0),
                          .controlChange(1, .bankSelectLSB, 0),
                          .programChange(1, 41)])
    }

    @Test
    func events_generalMIDI2_sendsBankBeforeProgram() throws {
        let part = Part<WallTime, NoteNumber>(name: "Part 1")
        let realization = try Realization(defaults: PatchTable([part.instrumentMap[.zero]: patchAssignment(.generalMIDI2(program: 20,
                                                                                                                         variation: 1))]))
        let performance = try #require(WorkPerformance(work: Work(content: .keyboardWall([part])),
                                                       realization: realization))

        #expect(performance.events.map(\.message) == [.controlChange(1, .bankSelectMSB, 121),
                                                      .controlChange(1, .bankSelectLSB, 1),
                                                      .programChange(1, 20),
                                                      .controlChange(1, .panMSB, 64)])
    }

    @Test
    func events_instrument_picksGeneralMIDIProgram() throws {
        var instrumentMap = InstrumentMap<WallTime>()

        try instrumentMap.insert(time: .zero,
                                 instrument: #require(Instrument(stringValue: "Violin")))
        try instrumentMap.insert(time: makeWallTime(2),
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
        #expect(programs == [WorkPerformance.Event(time: makeWallTime(0), message: .programChange(1, 41)),
                             WorkPerformance.Event(time: makeWallTime(2), message: .programChange(1, 1))])
    }

    @Test
    func events_panExact14Bit_sendsMSBThenLSB() throws {
        var part = try #require(makeKeyboardWallParts([[(0, 1, 60)]]).first)

        part.panMap.insert(time: .zero,
                           pan: .center,
                           extras: Extras(elements: [Extra(name: Extra.midiPan.name, values: [.int(64 * 128 + 8)])]))

        let performance = try #require(WorkPerformance(work: Work(content: .keyboardWall([part]))))

        #expect(panMessages(performance) == [.controlChange(1, .panMSB, 64),
                                             .controlChange(1, .panLSB, 8)])
    }

    @Test
    func events_panGlide_movesNoteByNoteAndSkipsRepeats() throws {
        var part = try #require(makeKeyboardWallParts([[(0, 1, 60), (2, 1, 62), (3, 1, 64), (6, 1, 65)]]).first)

        part.panMap.insert(time: .zero, pan: .left)
        part.panMap.insert(time: makeWallTime(4), pan: .center)

        let performance = try #require(WorkPerformance(work: Work(content: .keyboardWall([part]))))
        let pans = performance.events.compactMap { event -> (WallTime, UInt)? in
            guard case let .controlChange(_, .panMSB, value) = event.message
            else { return nil }

            return (event.time, value.uintValue)
        }

        //
        // Left at 0, partway at 2 and 3, centre at 4; the note at 6 is still centre, so nothing more.
        //
        #expect(pans.map(\.0) == [.zero, makeWallTime(2), makeWallTime(3), makeWallTime(4)])
        #expect(pans.first?.1 == 0)
        #expect(pans.last?.1 == 64)
        #expect(pans.dropFirst().dropLast().allSatisfy { (1..<64).contains($0.1) })
        #expect(pans[1].1 < pans[2].1)
    }

    @Test
    func events_panSharedChannel_firstPartWins() throws {
        var parts = makeKeyboardWallParts(Array(repeating: [(0, 1, 60)], count: 16))

        parts[15].panMap.insert(time: .zero, pan: .right)

        let performance = try #require(WorkPerformance(work: Work(content: .keyboardWall(parts))))
        let channelOnePans = panMessages(performance).filter { $0.channel == 1 }

        #expect(performance.partChannels[15] == 1)
        #expect(channelOnePans == [.controlChange(1, .panMSB, 64)])
    }

    @Test
    func events_percussion_playsOnChannel10() throws {
        let work = makeKeyboardWallWork([[(0, 1, 36)]])
        let part = try #require(work.part(work.partIDs[0], as: Part<WallTime, NoteNumber>.self))
        let realization = try Realization(defaults: PatchTable([part.instrumentMap[.zero]: patchAssignment(.generalMIDI1Percussion)]))
        let performance = try #require(WorkPerformance(work: work,
                                                       realization: realization))

        #expect(performance.events.map(\.message.channel.uintValue) == [10, 10, 10, 10])
        #expect(performance.partChannelSets.map { $0.map(\.uintValue) } == [[10]])
    }

    @Test
    func init_keyboardWallWork_sortsNotesByTime() throws {
        let performance = try #require(WorkPerformance(work: makeKeyboardWallWork([[(1, 0.5, 62)],
                                                                                   [(0, 2, 50)]])))
        let notes = performance.events.filter { isNoteMessage($0.message) }

        #expect(performance.duration == makeWallTime(2))
        #expect(notes == [WorkPerformance.Event(time: makeWallTime(0), message: .noteOn(2, 50, 64)),
                          WorkPerformance.Event(time: makeWallTime(1), message: .noteOn(1, 62, 64)),
                          WorkPerformance.Event(time: makeWallTime(1.5), message: .noteOff(1, 62, 0)),
                          WorkPerformance.Event(time: makeWallTime(2), message: .noteOff(2, 50, 0))])
    }

    @Test
    func init_otherWork_isNil() {
        #expect(WorkPerformance(work: Work(content: .standardBeat([], TempoMap()))) == nil)
        #expect(WorkPerformance(work: Work(content: .keyboardBeat([], TempoMap()))) == nil)
    }
}
