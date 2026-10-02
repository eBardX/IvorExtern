// © 2026 John Gary Pusey (see LICENSE.md)

public import IvorModel

extension Work {

    // MARK: Public Instance Properties

    /// A Boolean value indicating whether this work carries the timecode
    /// division of the Standard MIDI File it was imported from.
    ///
    /// Such a work’s times were measured in SMPTE frames, so exporting it as
    /// a Standard MIDI File writes it back with the same division. The
    /// division is recorded in an ``IvorModel/Extra/midiTimeCode`` extra; a
    /// division a Standard MIDI File can’t encode doesn’t count.
    public var hasMIDITimeCode: Bool {
        determineTimeCode(content) != nil
    }
}
