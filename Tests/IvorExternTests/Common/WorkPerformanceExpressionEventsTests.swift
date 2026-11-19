// © 2026 John Gary Pusey (see LICENSE.md)

import IvorExtern
import IvorMIDI
import IvorModel
import IvorTiming
import IvorTuning
import Testing
import XestiTools

struct WorkPerformanceExpressionEventsTests {
}

// MARK: -

extension WorkPerformanceExpressionEventsTests {
    @Test
    func events_crescendoOverHeldNote_risesToUnity() throws {
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
    func events_diminuendo_letsGoAtTheNextAttack() throws {
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
    func events_exactValuesPlayAsTheyAre() throws {
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
    func events_partWithoutExpression_dropsExactValues() throws {
        var part = try #require(makeKeyboardWallParts([[(0, 2, 60)]]).first)
        let extras = Extras(elements: [Extra(name: Extra.expressionValue.name, values: [.int(90 * 128 + 5)])])

        part.dynamicMap.insert(time: .zero, dynamic: .p)
        part.dynamicMap.insert(time: makeWallTime(1), dynamic: .p, extras: extras)

        let performance = try #require(WorkPerformance(work: Work(content: .keyboardWall([part])),
                                                       partsWithoutExpression: [0]))

        #expect(expressionValues(performance).isEmpty)
        #expect(noteOnVelocities(performance) == [51])
    }

    @Test
    func events_partWithoutExpression_sendsNoneAndKeepsPlainVelocities() throws {
        var parts = makeKeyboardWallParts([[(0, 6, 60)], [(0, 6, 64)]])

        for index in parts.indices {
            parts[index].dynamicMap.insert(time: .zero, dynamic: .p)
            parts[index].dynamicMap.insert(time: makeWallTime(6), dynamic: .f)
        }

        let performance = try #require(WorkPerformance(work: Work(content: .keyboardWall(parts)),
                                                       partsWithoutExpression: [1]))
        let channels = Set(performance.events.compactMap { event -> UInt? in
            guard case let .controlChange(channel, .expressionControllerMSB, _) = event.message
            else { return nil }

            return channel.uintValue
        })

        //
        // The first part still sends expression, and attacks at the peak's velocity (89); the second sends none, and
        // attacks at p's (51).
        //
        #expect(performance.partsWithoutExpression == [1])
        #expect(channels == [1])
        #expect(noteOnVelocities(performance) == [89, 51])
    }

    @Test
    func events_percussionAndSharedChannels_sendNone() throws {
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
    func events_spansInOneRun_shareAPeak() throws {
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
    func events_stepInsideASpan_fades() throws {
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
    func events_unmovingDynamics_sendUnityOnce() throws {
        var part = try #require(makeKeyboardWallParts([[(0, 2, 60), (2, 2, 62)]]).first)

        part.dynamicMap.insert(time: .zero, dynamic: .p)
        part.dynamicMap.insert(time: makeWallTime(1), dynamic: .p)
        part.dynamicMap.insert(time: makeWallTime(1), dynamic: .f)

        let performance = try #require(WorkPerformance(work: Work(content: .keyboardWall([part]))))

        #expect(expressionValues(performance).map(\.value) == [127])
        #expect(noteOnVelocities(performance) == [51, 89])
    }
}
