// © 2026 John Gary Pusey (see LICENSE.md)

public import IvorMIDI
public import IvorTiming

extension WorkPerformance {

    // MARK: Public Nested Types

    /// One channel message at its time in a work, exactly as the work has
    /// it.
    ///
    /// Events at the same time are ordered note-offs first, then bank
    /// selects (MSB, then LSB), then program changes, then note-ons, so that
    /// a note repeated back to back sounds again — with its new instrument,
    /// if the instrument changes there.
    public struct Event {

        // MARK: Public Initializers

        /// Creates an `Event` instance with the provided time and message.
        ///
        /// - Parameter time:       The time in the work.
        /// - Parameter message:    The message to send then.
        public init(time: WallTime,
                    message: MIDIChannelMessage) {
            self.message = message
            self.time = time
        }

        // MARK: Public Instance Properties

        /// The message to send.
        public let message: MIDIChannelMessage

        /// The time in the work.
        public let time: WallTime
    }
}

// MARK: -

extension WorkPerformance.Event {

    // MARK: Private Instance Properties

    private var rank: Int {
        switch message {
        case .controlChange(_, .bankSelectLSB, _):
            2

        case .controlChange(_, .bankSelectMSB, _):
            1

        case .noteOff:
            0

        case .noteOn:
            5

        case .programChange:
            3

        default:
            4
        }
    }
}

// MARK: - Comparable

extension WorkPerformance.Event: Comparable {

    // MARK: Public Type Methods

    /// Returns a Boolean value indicating whether the first event is sent
    /// before the second: at an earlier time or, at the same time, in the
    /// order ``WorkPerformance/Event`` describes.
    public static func < (lhs: Self,
                          rhs: Self) -> Bool {
        (lhs.time, lhs.rank) < (rhs.time, rhs.rank)
    }
}

// MARK: - Equatable

extension WorkPerformance.Event: Equatable {
}

// MARK: - Sendable

extension WorkPerformance.Event: Sendable {
}
