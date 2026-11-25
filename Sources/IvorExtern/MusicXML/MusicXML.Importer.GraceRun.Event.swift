// © 2026 John Gary Pusey (see LICENSE.md)

internal import IvorModel
internal import IvorMXL
internal import IvorTiming
internal import IvorTuning

extension MusicXML.Importer.GraceRun {

    // MARK: Internal Nested Types

    // One grace note, with the `<chord/>` grace notes after it: its pitches,
    // its written length (from its `<type>` and dots), and its `<grace>`
    // timing attributes.
    internal struct Event {

        // MARK: Internal Initializers

        internal init(length: PositiveDuration<BeatDuration>?,
                      makeTime: BeatDuration?,
                      pitches: [Pitch],
                      stealTimeFollowing: MXLPercent?,
                      stealTimePrevious: MXLPercent?) {
            self.length = length
            self.makeTime = makeTime
            self.stealTimeFollowing = stealTimeFollowing
            self.stealTimePrevious = stealTimePrevious
            self.pitches = pitches
        }

        // MARK: Internal Instance Properties

        internal let length: PositiveDuration<BeatDuration>?
        internal let makeTime: BeatDuration?
        internal let stealTimeFollowing: MXLPercent?
        internal let stealTimePrevious: MXLPercent?
        internal var pitches: [Pitch]
    }
}

// MARK: - Sendable

extension MusicXML.Importer.GraceRun.Event: Sendable {
}
