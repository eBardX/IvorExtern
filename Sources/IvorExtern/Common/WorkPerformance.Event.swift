// © 2026 John Gary Pusey (see LICENSE.md)

public import IvorMIDI
public import IvorTiming

extension WorkPerformance {

    // MARK: Public Nested Types

    /// One channel message at its time in a work, exactly as the work has
    /// it.
    ///
    /// Events at the same time are ordered note-offs first, then bank
    /// selects (MSB, then LSB), then program changes, then pan (MSB, then
    /// LSB), then expression (MSB, then LSB), then any other control
    /// change, then note-ons, so that a note repeated back to back sounds
    /// again — with its new instrument, pan and expression, if they change
    /// there.
    public struct Event {

        // MARK: Public Initializers

        /// Creates an `Event` instance with the provided time and message.
        ///
        /// - Parameter time:       The time in the work.
        /// - Parameter message:    The message to send then.
        /// - Parameter partIndex:  The index of the part whose note this
        ///                         is, or `nil` if it isn’t a note.
        public init(time: WallTime,
                    message: MIDIChannelMessage,
                    partIndex: Int? = nil) {
            self.message = message
            self.partIndex = partIndex
            self.time = time
        }

        // MARK: Public Instance Properties

        /// The message to send.
        public let message: MIDIChannelMessage

        /// The index of the part whose note this is, in the work’s order, or
        /// `nil` if it isn’t a note.
        ///
        /// Parts can share a channel, so a note’s channel doesn’t tell whose
        /// it is. Everything else on a channel belongs to the channel, not
        /// to a part.
        public let partIndex: Int?

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

        case .controlChange(_, .expressionControllerLSB, _):
            7

        case .controlChange(_, .expressionControllerMSB, _):
            6

        case .controlChange(_, .panLSB, _):
            5

        case .controlChange(_, .panMSB, _):
            4

        case .noteOff:
            0

        case .noteOn:
            9

        case .programChange:
            3

        default:
            8
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
