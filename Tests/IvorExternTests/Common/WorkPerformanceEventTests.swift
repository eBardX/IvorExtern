// © 2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import IvorMIDI
import IvorTiming
import Testing
import XestiTools

struct WorkPerformanceEventTests {
}

// MARK: -

extension WorkPerformanceEventTests {
    @Test
    func comparable_earlierTime_sortsFirst() {
        let early = WorkPerformance.Event(time: .zero,
                                          message: .noteOn(1, 60, 100))
        let late = WorkPerformance.Event(time: WallTime(1_000_000),
                                         message: .noteOff(1, 60, 0))

        #expect(early < late)
        #expect(!(late < early))
    }

    @Test
    func comparable_equalEvents_neitherIsLess() {
        let lhs = WorkPerformance.Event(time: .zero,
                                        message: .noteOn(1, 60, 100))
        let rhs = WorkPerformance.Event(time: .zero,
                                        message: .noteOn(1, 60, 100))

        #expect(!(lhs < rhs))
        #expect(!(rhs < lhs))
    }

    @Test
    func comparable_sameTime_ordersByMessageKind() {
        let messages: [MIDIChannelMessage] = [.noteOff(1, 60, 0),
                                              .controlChange(1, .bankSelectMSB, 121),
                                              .controlChange(1, .bankSelectLSB, 1),
                                              .programChange(1, 20),
                                              .controlChange(1, .panMSB, 64),
                                              .controlChange(1, .panLSB, 0),
                                              .controlChange(1, .brightness, 64),
                                              .noteOn(1, 60, 100)]
        let events = messages.map { WorkPerformance.Event(time: .zero, message: $0) }

        #expect(events.reversed().sorted() == events)
    }

    @Test
    func equality() {
        let event = WorkPerformance.Event(time: .zero,
                                          message: .noteOn(1, 60, 100))

        #expect(event == WorkPerformance.Event(time: .zero, message: .noteOn(1, 60, 100)))
        #expect(event != WorkPerformance.Event(time: .zero, message: .noteOn(1, 62, 100)))
    }

    @Test
    func init_storesTimeAndMessage() {
        let event = WorkPerformance.Event(time: WallTime(2_000_000),
                                          message: .programChange(3, 41))

        #expect(event.time == WallTime(2_000_000))
        #expect(event.message == .programChange(3, 41))
    }
}
