// © 2026 John Gary Pusey (see LICENSE.md)

public import IvorGeneralMIDI
public import IvorModel

extension Instrument {

    // MARK: Public Instance Properties

    /// The General MIDI Level 1 instrument this instrument’s name matches,
    /// or `nil` if it matches none.
    ///
    /// The name is matched as ``IvorGeneralMIDI/GM1Instrument/init(name:)``
    /// matches it.
    public var generalMIDIInstrument: GM1Instrument? {
        GM1Instrument(name: stringValue)
    }
}
