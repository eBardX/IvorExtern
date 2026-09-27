// © 2026 John Gary Pusey (see LICENSE.md)

internal import IvorTiming

extension MIDI {

    // MARK: Internal Nested Types

    // Maps SMF event times to model times on import: `MIDI.BeatMap` to beat
    // times, `MIDI.WallMap` to wall times.
    internal protocol ImportTimeMap: Sendable {

        // MARK: Internal Associated Types

        associatedtype TimeType: TimeProtocol

        // MARK: Internal Instance Methods

        func time(at eventTime: MIDI.EventTime) -> TimeType

        func timeSpan(at eventTime: MIDI.EventTime,
                      ticks: UInt) -> (TimeType, TimeType.DurationType)
    }
}
