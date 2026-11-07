// © 2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import IvorMIDI
import IvorModel
import IvorTiming
import IvorTuning
import Testing
import XestiNumbers
import XestiTools

struct WorkPerformanceExpressionTests {
}

// MARK: -

extension WorkPerformanceExpressionTests {
    @Test
    func events_crescendoOverHeldNote_risesToUnity() throws {
        var part = try #require(makeKeyboardWallParts([[(0, 6, 60)]]).first)

        part.dynamicMap.insert(time: .zero, dynamic: .p)
        part.dynamicMap.insert(time: makeWallTime(6), dynamic: .f)

        let events = WorkPerformance.Expression(part: part).events(on: [1])

        #expect(events.first?.time == .zero)
        #expect(events.first?.message == .controlChange(1, .expressionControllerMSB, 73))
        #expect(try #require(events.last).time < makeWallTime(6))
        #expect(events.last?.message == .controlChange(1, .expressionControllerMSB, 127))
    }

    @Test
    func events_exactValueAtZero_sendsNoUnityFirst() throws {
        var part = try #require(makeKeyboardWallParts([[(0, 2, 60)]]).first)

        part.dynamicMap.insert(time: .zero,
                               dynamic: .p,
                               extras: Extras(elements: [Extra(name: Extra.expressionValue.name, values: [.int(90 * 128 + 5)])]))

        let events = WorkPerformance.Expression(part: part).events(on: [1])

        #expect(events == [WorkPerformance.Event(time: .zero, message: .controlChange(1, .expressionControllerMSB, 90)),
                           WorkPerformance.Event(time: .zero, message: .controlChange(1, .expressionControllerLSB, 5))])
    }

    @Test
    func events_exactValueLater_sendsUnityFirst() throws {
        var part = try #require(makeKeyboardWallParts([[(0, 2, 60)]]).first)
        let time = makeWallTime(1)

        part.dynamicMap.insert(time: time,
                               dynamic: .p,
                               extras: Extras(elements: [Extra(name: Extra.expressionValue.name, values: [.int(90 * 128 + 5)])]))

        let events = WorkPerformance.Expression(part: part).events(on: [1])

        #expect(events == [WorkPerformance.Event(time: .zero, message: .controlChange(1, .expressionControllerMSB, 127)),
                           WorkPerformance.Event(time: time, message: .controlChange(1, .expressionControllerMSB, 90)),
                           WorkPerformance.Event(time: time, message: .controlChange(1, .expressionControllerLSB, 5))])
    }

    @Test
    func events_noChannels_isEmpty() throws {
        let part = try #require(makeKeyboardWallParts([[(0, 1, 60)]]).first)

        #expect(WorkPerformance.Expression(part: part).events(on: []).isEmpty)
    }

    @Test
    func events_rampOverSilence_sendsUnityOnce() throws {
        var part = try #require(makeKeyboardWallParts([[(8, 1, 60)]]).first)

        part.dynamicMap.insert(time: makeWallTime(2), dynamic: .p)
        part.dynamicMap.insert(time: makeWallTime(4), dynamic: .f)

        let events = WorkPerformance.Expression(part: part).events(on: [1])

        #expect(events == [WorkPerformance.Event(time: .zero, message: .controlChange(1, .expressionControllerMSB, 127))])
    }

    @Test
    func events_rampTooSmallToHear_sendsUnityOnce() throws {
        var part = try #require(makeKeyboardWallParts([[(0, 6, 60)]]).first)

        try part.dynamicMap.insert(time: .zero, dynamic: #require(Dynamic(numberValue: Number(0.5))))
        try part.dynamicMap.insert(time: makeWallTime(6), dynamic: #require(Dynamic(numberValue: Number(0.51))))

        let events = WorkPerformance.Expression(part: part).events(on: [1])

        #expect(events == [WorkPerformance.Event(time: .zero, message: .controlChange(1, .expressionControllerMSB, 127))])
    }

    @Test
    func events_severalChannels_sendsOnEach() throws {
        let part = try #require(makeKeyboardWallParts([[(0, 1, 60)]]).first)

        let events = WorkPerformance.Expression(part: part).events(on: [1, 2])

        #expect(events == [WorkPerformance.Event(time: .zero, message: .controlChange(1, .expressionControllerMSB, 127)),
                           WorkPerformance.Event(time: .zero, message: .controlChange(2, .expressionControllerMSB, 127))])
    }

    @Test
    func gridTimes_noNotes_isEmpty() throws {
        let part = try #require(makeKeyboardWallParts([[]]).first)

        #expect(WorkPerformance.Expression(part: part).gridTimes(from: .zero, through: makeWallTime(1)).isEmpty)
    }

    @Test
    func gridTimes_onlyWhileANoteSounds() throws {
        let part = try #require(makeKeyboardWallParts([[(1, 1, 60)]]).first)

        let times = WorkPerformance.Expression(part: part).gridTimes(from: .zero, through: makeWallTime(3))

        #expect(times.count == 50)
        #expect(times.first == makeWallTime(1))
        #expect(times.last == makeWallTime(1.98))
    }

    @Test
    func velocity_exactValues_isUnchanged() throws {
        var part = try #require(makeKeyboardWallParts([[(0, 6, 60)]]).first)

        part.dynamicMap.insert(time: .zero,
                               dynamic: .p,
                               extras: Extras(elements: [Extra(name: Extra.expressionValue.name, values: [.int(1_000)])]))
        part.dynamicMap.insert(time: makeWallTime(6), dynamic: .f)

        #expect(WorkPerformance.Expression(part: part).velocity(51, at: .zero) == 51)
    }

    @Test
    func velocity_insideSpan_compensatesForTheGain() throws {
        var part = try #require(makeKeyboardWallParts([[(0, 6, 60)]]).first)

        part.dynamicMap.insert(time: .zero, dynamic: .p)
        part.dynamicMap.insert(time: makeWallTime(6), dynamic: .f)

        #expect(WorkPerformance.Expression(part: part).velocity(51, at: .zero) == 89)
    }

    @Test
    func velocity_insideSpan_stopsAt127() throws {
        var part = try #require(makeKeyboardWallParts([[(0, 6, 60)]]).first)

        part.dynamicMap.insert(time: .zero, dynamic: .p)
        part.dynamicMap.insert(time: makeWallTime(6), dynamic: .f)

        #expect(WorkPerformance.Expression(part: part).velocity(127, at: .zero) == 127)
    }

    @Test
    func velocity_noSpans_isUnchanged() throws {
        let part = try #require(makeKeyboardWallParts([[(0, 1, 60)]]).first)

        #expect(WorkPerformance.Expression(part: part).velocity(51, at: .zero) == 51)
    }
}
