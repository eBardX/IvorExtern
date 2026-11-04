// © 2026 John Gary Pusey (see LICENSE.md)

internal import IvorModel
internal import IvorMXL
internal import XestiTools

// A note's own `dynamics` and `end-dynamics` attributes are its attack and
// release velocities, each a percentage of the default forte velocity (90,
// per the MIDI 1.0 convention the MusicXML spec cites), so they convert to
// and from a note's `attackVelocity` and `releaseVelocity` extras (see
// `Extra+Ivor.swift`) on MIDI's own 1-127 scale.

// MARK: Internal Functions

// The exact key velocity (MIDI-style 1-127 scale) a note's own `dynamics`
// percent converts to, kept on the note as its `attackVelocity` extra (see
// `Extra+Ivor.swift`).
internal func convertToAttackVelocity(_ note: MXLNote) -> Int? {
    _convertToVelocity(percent: note.dynamics)
}

// The reverse of `convertToReleaseVelocity(_:)`: a note's `releaseVelocity`
// extra as an `end-dynamics` percent of the default forte velocity (90),
// rounded to two decimal places — fine enough that it converts back to the
// same velocity. Unlike a note's `attackVelocity`, which `MusicXML.Exporter`
// never writes as a `dynamics` attribute (see `_makeChunks`), this one can't
// pre-empt any direction-level dynamic, so it's always written when present.
internal func convertToMusicXMLEndDynamics(_ extras: Extras?) -> MXLNonNegativeDecimal? {
    intValue(extras, .releaseVelocity).flatMap(_convertToMusicXMLPercent(velocity:))
}

// The exact key velocity (MIDI-style 1-127 scale) a note's own
// `end-dynamics` percent converts to, kept on the note as its
// `releaseVelocity` extra (see `Extra+Ivor.swift`).
internal func convertToReleaseVelocity(_ note: MXLNote) -> Int? {
    _convertToVelocity(percent: note.endDynamics)
}

// MARK: Private Functions

// A velocity as a percent of the default forte velocity (90, per the MIDI
// 1.0 convention the MusicXML spec cites), rounded to two decimal places.
// `nil` for a velocity outside 1-127.
private func _convertToMusicXMLPercent(velocity: Int) -> MXLNonNegativeDecimal? {
    guard (1...127).contains(velocity)
    else { return nil }

    return (Double(velocity) / 90 * 10_000).rounded() / 100
}

private func _convertToVelocity(percent: MXLNonNegativeDecimal?) -> Int? {
    guard let percent,
          percent > 0
    else { return nil }

    let velocity = percent / 100 * 90

    return min(127, max(1, Int(velocity.rounded())))
}
