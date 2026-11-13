// © 2026 John Gary Pusey (see LICENSE.md)

internal import IvorModel
internal import IvorTiming
internal import XestiTools

// One bar of a work as an exporter writes it (see `exportBars(_:through:)`):
// where it starts, how long it actually is, the meter it's in, and whether
// that meter is written at its start. `extras` are those of the meter entry
// that governs the bar, for a `meterSymbol`. A pickup bar is the opening
// part-bar, shorter than its meter's bar length.
internal struct ExportBar {

    // MARK: Internal Instance Properties

    internal let extras: Extras?
    internal let isMeterWritten: Bool
    internal let isPickup: Bool
    internal let length: BeatDuration
    internal let meter: Meter
    internal let start: BeatTime
}

// MARK: -

extension ExportBar {

    // MARK: Internal Instance Properties

    internal var end: BeatTime {
        start + length
    }
}

// MARK: - Sendable

extension ExportBar: Sendable {
}
