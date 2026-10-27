// © 2026 John Gary Pusey (see LICENSE.md)

public import IvorModel

private import IvorGeneralMIDI
private import IvorMIDI

extension Patch {

    // MARK: Public Instance Properties

    /// The General MIDI name of this patch’s sound, or `nil` if it has none.
    ///
    /// A General MIDI Level 2 instrument is named by its variation, or by
    /// its General MIDI Level 1 instrument if the variation has no name of
    /// its own; a General MIDI Level 2 drum set is named only if its program
    /// is one of the standard drum sets. A custom patch, or the General MIDI
    /// Level 1 percussion patch, has no General MIDI name.
    public var generalMIDIName: String? {
        switch kind {
        case .custom,
             .generalMIDI1Percussion:
            nil

        case let .generalMIDI1(program):
            GM1Instrument(program: MIDIProgram(clamping: program)).name

        case let .generalMIDI2(program, variation):
            GM2Instrument(bankLSB: MIDIData1Value(clamping: variation),
                          program: MIDIProgram(clamping: program))?.name
                ?? GM1Instrument(program: MIDIProgram(clamping: program)).name

        case let .generalMIDI2DrumSet(program):
            GM2DrumSet(program: MIDIProgram(clamping: program))?.name
        }
    }
}
