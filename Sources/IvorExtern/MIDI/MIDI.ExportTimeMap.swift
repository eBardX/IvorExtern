// © 2026 John Gary Pusey (see LICENSE.md)

internal import IvorTiming

extension MIDI {

    // MARK: Internal Nested Types

    // Maps model times to SMF event times on export: `MIDI.TickMap` from
    // beat times, `MIDI.WallTickMap` from wall times.
    internal protocol ExportTimeMap: Sendable {

        // MARK: Internal Associated Types

        associatedtype TimeType: TimeProtocol

        // MARK: Internal Instance Methods

        func eventTime(at time: TimeType) -> MIDI.EventTime?

        // The release time of a note, throwing if its duration is zero.
        func releaseTime(attack: TimeType,
                         duration: TimeType.DurationType) throws(MIDI.Error) -> TimeType
    }
}
