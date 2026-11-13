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
    func event_sameTime_ordersOffsBanksProgramsPansExpressionPedalsOns() {
        let time = makeWallTime(1)
        let ordered: [MIDIChannelMessage] = [.noteOff(1, 60, 0),
                                             .controlChange(1, .bankSelectMSB, 121),
                                             .controlChange(1, .bankSelectLSB, 1),
                                             .programChange(1, 20),
                                             .controlChange(1, .panMSB, 64),
                                             .controlChange(1, .panLSB, 8),
                                             .controlChange(1, .expressionControllerMSB, 100),
                                             .controlChange(1, .expressionControllerLSB, 3),
                                             .controlChange(1, .sustain, 0),
                                             .controlChange(1, .channelVolumeMSB, 90),
                                             .noteOn(1, 60, 100)]
        let events = ordered.reversed().map { WorkPerformance.Event(time: time, message: $0) }

        #expect(events.sorted().map(\.message) == ordered)
        #expect(WorkPerformance.Event(time: .zero, message: .noteOn(1, 60, 100))
            < WorkPerformance.Event(time: time, message: .noteOff(1, 60, 0)))
    }

    @Test
    func events_assignment_overridesGeneralMIDIName() throws {
        let part = Part<WallTime, NoteNumber>(name: "Part 1")
        let realization = try Realization(defaults: PatchTable([part.instrumentTable[.zero]: patchAssignment(.generalMIDI1(program: 20))]))
        let performance = try #require(WorkPerformance(work: Work(content: .keyboardWall([part])),
                                                       realization: realization))

        #expect(messagesWithoutExpression(performance) == [.programChange(1, 20),
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
        let realization = Realization(defaults: PatchTable([part.instrumentTable[.zero]: assignment]))
        let performance = try #require(WorkPerformance(work: Work(content: .keyboardWall([part])),
                                                       realization: realization))
        let expected: [MIDIChannelMessage] = [.controlChange(1, .bankSelectMSB, 121),
                                              .controlChange(1, .bankSelectLSB, 1),
                                              .programChange(1, 5),
                                              .controlChange(1, .panMSB, 64)]

        #expect(messagesWithoutExpression(performance) == expected)
    }

    @Test
    func events_durationIncludesAPedalUpAfterTheLastNote() throws {
        var parts = makeKeyboardWallParts([[(0, 1, 60)]])

        parts[0].pedals[.sustain] = wallSustainTable([(0, .down), (3, .up)])

        let performance = try #require(WorkPerformance(work: Work(content: .keyboardWall(parts))))

        #expect(performance.duration == makeWallTime(3))
    }

    @Test
    func events_dynamicRamp_risesNoteByNote() throws {
        var part = try #require(makeKeyboardWallParts([[(0, 0.05, 60), (2, 0.05, 62), (4, 0.05, 64)]]).first)

        part.dynamicMap.insert(time: .zero, dynamic: .pp)
        part.dynamicMap.insert(time: makeWallTime(4), dynamic: .ff)

        let performance = try #require(WorkPerformance(work: Work(content: .keyboardWall([part]))))

        //
        // pp is 0.3 and ff 0.8, so halfway is 0.55: 38, 70 and 102 out of 127. No note lasts long enough to drift.
        //
        #expect(noteOnVelocities(performance) == [38, 70, 102])
        #expect(expressionValues(performance).map(\.value) == [127])
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
    func events_expression_crescendoOverHeldNote_risesToUnity() throws {
        var part = try #require(makeKeyboardWallParts([[(0, 6, 60), (3, 1, 67)]]).first)

        part.dynamicMap.insert(time: .zero, dynamic: .p)
        part.dynamicMap.insert(time: makeWallTime(6), dynamic: .f)

        let performance = try #require(WorkPerformance(work: Work(content: .keyboardWall([part]))))
        let values = expressionValues(performance)

        //
        // p is 0.4 and f 0.7, so the gain goes from 73 to 127, and every attack has the peak's velocity: 89.
        //
        #expect(values.first?.time == .zero)
        #expect(values.first?.value == 73)
        #expect(values.last?.value == 127)
        #expect(zip(values, values.dropFirst()).allSatisfy { $0.value < $1.value })
        #expect(noteOnVelocities(performance) == [89, 89])
    }

    @Test
    func events_expression_diminuendo_letsGoAtTheNextAttack() throws {
        var part = try #require(makeKeyboardWallParts([[(0, 6, 60), (8, 1, 62)]]).first)

        part.dynamicMap.insert(time: makeWallTime(2), dynamic: .f)
        part.dynamicMap.insert(time: makeWallTime(4), dynamic: .p)

        let performance = try #require(WorkPerformance(work: Work(content: .keyboardWall([part]))))
        let values = expressionValues(performance)

        //
        // Unity through the note's start, no change at its release at 6, and back to unity for the note at 8, whose
        // velocity is then the plain level.
        //
        #expect(values.first?.value == 127)
        #expect(values.last?.time == makeWallTime(8))
        #expect(values.last?.value == 127)
        #expect(try #require(values.dropLast().last).time <= makeWallTime(4))
        #expect(values.dropLast().last?.value == 73)
        #expect(noteOnVelocities(performance) == [89, 51])
    }

    @Test
    func events_expression_exactValuesPlayAsTheyAre() throws {
        var part = try #require(makeKeyboardWallParts([[(0, 2, 60)]]).first)
        let extras = Extras(elements: [Extra(name: Extra.expressionValue.name, values: [.int(90 * 128 + 5)])])

        part.dynamicMap.insert(time: .zero, dynamic: .p)
        part.dynamicMap.insert(time: makeWallTime(1), dynamic: .p, extras: extras)
        part.dynamicMap.insert(time: makeWallTime(2), dynamic: .f)

        let performance = try #require(WorkPerformance(work: Work(content: .keyboardWall([part]))))
        let messages = performance.events.filter { $0.time == makeWallTime(1) }.map(\.message)

        #expect(messages == [.controlChange(1, .expressionControllerMSB, 90),
                             .controlChange(1, .expressionControllerLSB, 5)])
        #expect(expressionValues(performance).map(\.value) == [127, 90])
        #expect(noteOnVelocities(performance) == [51])
    }

    @Test
    func events_expression_percussionAndSharedChannels_sendNone() throws {
        var parts = makeKeyboardWallParts(Array(repeating: [(0, 2, 60)], count: 16))

        parts[15].dynamicMap.insert(time: .zero, dynamic: .p)
        parts[15].dynamicMap.insert(time: makeWallTime(2), dynamic: .f)

        let performance = try #require(WorkPerformance(work: Work(content: .keyboardWall(parts))))
        let channels = performance.events.compactMap { event -> UInt? in
            guard case let .controlChange(channel, .expressionControllerMSB, _) = event.message
            else { return nil }

            return channel.uintValue
        }

        #expect(channels.sorted() == [1, 2, 3, 4, 5, 6, 7, 8, 9, 11, 12, 13, 14, 15, 16])

        //
        // The last part shares channel 1, so its attack stays at its plain velocity: p, not the peak's.
        //
        #expect(noteOnVelocities(performance).contains(51))
        #expect(!noteOnVelocities(performance).contains(89))
    }

    @Test
    func events_expression_spansInOneRun_shareAPeak() throws {
        var part = try #require(makeKeyboardWallParts([[(0, 10, 60)]]).first)

        part.dynamicMap.insert(time: makeWallTime(1), dynamic: .f)
        part.dynamicMap.insert(time: makeWallTime(2), dynamic: .p)
        part.dynamicMap.insert(time: makeWallTime(5), dynamic: .p)
        part.dynamicMap.insert(time: makeWallTime(6), dynamic: .ff)

        let performance = try #require(WorkPerformance(work: Work(content: .keyboardWall([part]))))
        let values = expressionValues(performance)

        //
        // The peak is ff, 0.8, so f starts at 111, p is 64, and nothing jumps by more than a grid step's worth.
        //
        #expect(values.first?.value == 111)
        #expect(values.contains { $0.value == 64 })
        #expect(zip(values, values.dropFirst()).allSatisfy { abs(Int($0.value) - Int($1.value)) <= 2 })
        #expect(noteOnVelocities(performance) == [102])
    }

    @Test
    func events_expression_stepInsideASpan_fades() throws {
        var part = try #require(makeKeyboardWallParts([[(0, 6, 60)]]).first)

        part.dynamicMap.insert(time: makeWallTime(1), dynamic: .p)
        part.dynamicMap.insert(time: makeWallTime(2), dynamic: .f)
        part.dynamicMap.insert(time: makeWallTime(3), dynamic: .f)
        part.dynamicMap.insert(time: makeWallTime(3), dynamic: .p)
        part.dynamicMap.insert(time: makeWallTime(4), dynamic: .f)

        let performance = try #require(WorkPerformance(work: Work(content: .keyboardWall([part]))))
        let values = expressionValues(performance)

        #expect(values.contains { $0.time > makeWallTime(2.96) && $0.time < makeWallTime(3) && (74..<127).contains($0.value) })
    }

    @Test
    func events_expression_unmovingDynamics_sendUnityOnce() throws {
        var part = try #require(makeKeyboardWallParts([[(0, 2, 60), (2, 2, 62)]]).first)

        part.dynamicMap.insert(time: .zero, dynamic: .p)
        part.dynamicMap.insert(time: makeWallTime(1), dynamic: .p)
        part.dynamicMap.insert(time: makeWallTime(1), dynamic: .f)

        let performance = try #require(WorkPerformance(work: Work(content: .keyboardWall([part]))))

        #expect(expressionValues(performance).map(\.value) == [127])
        #expect(noteOnVelocities(performance) == [51, 89])
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
        let realization = try Realization(defaults: PatchTable([part.instrumentTable[.zero]: patchAssignment(.generalMIDI2(program: 20,
                                                                                                                           variation: 1))]))
        let performance = try #require(WorkPerformance(work: Work(content: .keyboardWall([part])),
                                                       realization: realization))

        #expect(messagesWithoutExpression(performance) == [.controlChange(1, .bankSelectMSB, 121),
                                                           .controlChange(1, .bankSelectLSB, 1),
                                                           .programChange(1, 20),
                                                           .controlChange(1, .panMSB, 64)])
    }

    @Test
    func events_instrument_picksGeneralMIDIProgram() throws {
        var instrumentTable = InstrumentTable<WallTime>()

        try instrumentTable.insert(time: .zero,
                                   instrument: #require(Instrument(stringValue: "Violin")))
        try instrumentTable.insert(time: makeWallTime(2),
                                   instrument: #require(Instrument(stringValue: "Not a GM Name")))

        let part = Part<WallTime, NoteNumber>(name: "Part 1",
                                              instrumentTable: instrumentTable)
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
    func events_notesSayWhichPartTheyBelongTo() throws {
        // The last of 16 parts shares channel 1 with the first.
        let performance = try #require(WorkPerformance(work: makeKeyboardWallWork(Array(repeating: [(0, 1, 60)],
                                                                                        count: 16))))
        let notes = performance.events.filter {
            switch $0.message {
            case .noteOff,
                 .noteOn:
                true

            default:
                false
            }
        }

        #expect(Set(notes.compactMap(\.partIndex)) == Set(0..<16))
        #expect(notes.allSatisfy { $0.partIndex != nil })
        #expect(performance.events.filter { $0.partIndex != nil }.count == notes.count)
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
    func events_panGlide_streamsWhileNotesSoundAndSkipsRepeats() throws {
        var part = try #require(makeKeyboardWallParts([[(0, 1, 60), (2, 1, 62), (6, 1, 65)]]).first)

        part.panMap.insert(time: .zero, pan: .left)
        part.panMap.insert(time: makeWallTime(4), pan: .center)

        let performance = try #require(WorkPerformance(work: Work(content: .keyboardWall([part]))))
        let pans = performance.events.compactMap { event -> (WallTime, UInt)? in
            guard case let .controlChange(_, .panMSB, value) = event.message
            else { return nil }

            return (event.time, value.uintValue)
        }

        //
        // It moves through each note and sends nothing in the silences, except at the entry at 4.
        //
        #expect(pans.first?.0 == .zero)
        #expect(pans.first?.1 == 0)
        #expect(pans.last?.0 == makeWallTime(4))
        #expect(pans.last?.1 == 64)
        #expect(pans.contains { $0.0 > .zero && $0.0 < makeWallTime(1) })
        #expect(pans.contains { $0.0 > makeWallTime(2) && $0.0 < makeWallTime(3) })
        #expect(!pans.contains { $0.0 >= makeWallTime(1) && $0.0 < makeWallTime(2) })
        #expect(!pans.contains { $0.0 >= makeWallTime(3) && $0.0 < makeWallTime(4) })
        #expect(zip(pans, pans.dropFirst()).allSatisfy { $0.1 < $1.1 })
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
    func events_pedalDownAtAnAttack_precedesTheNoteOn() throws {
        var parts = makeKeyboardWallParts([[(1, 1, 60)]])

        parts[0].pedals[.sustain] = wallSustainTable([(1, .down)])

        let performance = try #require(WorkPerformance(work: Work(content: .keyboardWall(parts))))
        let messages = performance.events.filter { $0.time == makeWallTime(1) }.map(\.message)
        let pedalIndex = try #require(messages.firstIndex(of: .controlChange(1, .sustain, 127)))
        let noteOnIndex = try #require(messages.firstIndex { if case .noteOn = $0 { true } else { false } })

        #expect(pedalIndex < noteOnIndex)
    }

    @Test
    func events_percussion_playsOnChannel10() throws {
        let work = makeKeyboardWallWork([[(0, 1, 36)]])
        let part = try #require(work.part(work.partIDs[0], as: Part<WallTime, NoteNumber>.self))
        let realization = try Realization(defaults: PatchTable([part.instrumentTable[.zero]: patchAssignment(.generalMIDI1Percussion)]))
        let performance = try #require(WorkPerformance(work: work,
                                                       realization: realization))

        #expect(performance.events.map(\.message.channel.uintValue) == [10, 10, 10, 10])
        #expect(performance.partChannelSets.map { $0.map(\.uintValue) } == [[10]])
    }

    @Test
    func events_percussionChannel_getsPedals() throws {
        var parts = makeKeyboardWallParts([[(0, 1, 36)]])

        parts[0].pedals[.sustain] = wallSustainTable([(0, .down)])

        let work = Work(content: .keyboardWall(parts))
        let realization = try Realization(defaults: PatchTable([parts[0].instrumentTable[.zero]: patchAssignment(.generalMIDI1Percussion)]))
        let performance = try #require(WorkPerformance(work: work,
                                                       realization: realization))

        #expect(pedalMessages(performance) == [.controlChange(10, .sustain, 127)])
    }

    @Test
    func events_portamento_isNotSent() throws {
        var parts = makeKeyboardWallParts([[(0, 1, 60)]])
        var portamento = PedalTable<WallTime>()

        portamento.insert(time: .zero, level: .down)
        parts[0].pedals[.portamento] = portamento

        let performance = try #require(WorkPerformance(work: Work(content: .keyboardWall(parts))))

        #expect(pedalMessages(performance).isEmpty)
    }

    @Test
    func events_repedal_sendsOffThenOnAtOneTime() throws {
        var parts = makeKeyboardWallParts([[(0, 1, 60), (1, 1, 62)]])

        parts[0].pedals[.sustain] = wallSustainTable([(0, .down), (1, .up), (1, .down), (2, .up)])

        let performance = try #require(WorkPerformance(work: Work(content: .keyboardWall(parts))))
        let atOne = performance.events.filter { $0.time == makeWallTime(1) }.map(\.message)

        #expect(pedalMessages(performance) == [.controlChange(1, .sustain, 127),
                                               .controlChange(1, .sustain, 0),
                                               .controlChange(1, .sustain, 127),
                                               .controlChange(1, .sustain, 0)])
        #expect(Array(atOne.dropLast()) == [.noteOff(1, 60, 0),
                                            .controlChange(1, .sustain, 0),
                                            .controlChange(1, .sustain, 127)])

        guard case .noteOn(1, 62, _)? = atOne.last
        else { Issue.record("Expected the note-on last"); return }
    }

    @Test
    func events_sharedChannel_firstPartWins() throws {
        var parts = makeKeyboardWallParts(Array(repeating: [(0, 1, 60)], count: 16))

        parts[15].pedals[.sustain] = wallSustainTable([(0, .down)])

        let performance = try #require(WorkPerformance(work: Work(content: .keyboardWall(parts))))

        #expect(performance.partChannels[15] == 1)
        #expect(pedalMessages(performance).isEmpty)
    }

    @Test
    func events_sustainEntries_becomeCC64OnEachOwnedChannel() throws {
        var parts = makeKeyboardWallParts([[(0, 1, 60)], [(0, 1, 64)]])

        parts[1].pedals[.sustain] = wallSustainTable([(0, .down), (2, .up)])

        let performance = try #require(WorkPerformance(work: Work(content: .keyboardWall(parts))))

        #expect(pedalMessages(performance) == [.controlChange(2, .sustain, 127),
                                               .controlChange(2, .sustain, 0)])
    }

    @Test
    func init_keyboardWallWork_sortsNotesByTime() throws {
        let performance = try #require(WorkPerformance(work: makeKeyboardWallWork([[(1, 0.5, 62)],
                                                                                   [(0, 2, 50)]])))
        let notes = performance.events.filter { isNoteMessage($0.message) }

        #expect(performance.duration == makeWallTime(2))
        #expect(notes == [WorkPerformance.Event(time: makeWallTime(0), message: .noteOn(2, 50, 64), partIndex: 1),
                          WorkPerformance.Event(time: makeWallTime(1), message: .noteOn(1, 62, 64), partIndex: 0),
                          WorkPerformance.Event(time: makeWallTime(1.5), message: .noteOff(1, 62, 0), partIndex: 0),
                          WorkPerformance.Event(time: makeWallTime(2), message: .noteOff(2, 50, 0), partIndex: 1)])
    }

    @Test
    func init_otherWork_isNil() {
        #expect(WorkPerformance(work: Work(content: .standardBeat([], TempoMap(), MeterTable()))) == nil)
        #expect(WorkPerformance(work: Work(content: .keyboardBeat([], TempoMap(), MeterTable()))) == nil)
    }

    @Test
    func ownedChannelSets_leaveOutWhatAnEarlierPartPlaysOn() throws {
        let performance = try #require(WorkPerformance(work: makeKeyboardWallWork(Array(repeating: [(0, 1, 60)],
                                                                                        count: 16))))

        #expect(performance.ownedChannelSets.first?.map(\.uintValue) == [1])
        #expect(performance.ownedChannelSets.last?.isEmpty == true)
        #expect(performance.ownedChannelSets.count == 16)
    }
}
