// © 2026 John Gary Pusey (see LICENSE.md)

public import IvorMIDI
public import IvorModel

private import IvorGeneralMIDI

extension MIDIPatch {

    // MARK: Public Initializers

    /// Creates a `MIDIPatch` instance for the provided instrument, which has
    /// no patch of its own.
    ///
    /// The instrument sounds as the General MIDI Level 1 instrument its name
    /// matches (see ``IvorModel/Instrument/generalMIDIInstrument``), or as
    /// the first program (Acoustic Grand Piano) if its name matches none. No
    /// bank is selected.
    ///
    /// - Parameter instrument: The instrument.
    public init(instrument: Instrument) {
        self.init(program: instrument.generalMIDIInstrument?.program ?? MIDIProgram(clamping: 1))
    }

    /// Creates a `MIDIPatch` instance for the provided patch.
    ///
    /// A General MIDI Level 2 instrument is in bank MSB 121, with its
    /// variation as the LSB, and a General MIDI Level 2 drum set in bank
    /// MSB 120, LSB 0. A custom patch is in its own bank, if it names one.
    /// A General MIDI Level 1 instrument, the General MIDI Level 1
    /// percussion patch, or a custom patch without a bank selects no bank.
    ///
    /// - Parameter patch:  The patch.
    public init(patch: Patch) {
        switch patch.kind {
        case let .custom(program, bank, _):
            self.init(program: MIDIProgram(clamping: program),
                      bank: bank.flatMap(UInt.init(exactly:)).flatMap(MIDIBank.init(uintValue:)))

        case let .generalMIDI1(program):
            self.init(program: MIDIProgram(clamping: program))

        case .generalMIDI1Percussion:
            self.init(program: MIDIProgram(clamping: 1))

        case let .generalMIDI2(program, variation):
            self.init(program: MIDIProgram(clamping: program),
                      bank: MIDIBank(msb: GM2Instrument.bankMSB,
                                     lsb: MIDIData1Value(clamping: variation)))

        case let .generalMIDI2DrumSet(program):
            self.init(program: MIDIProgram(clamping: program),
                      bank: MIDIBank(msb: GM2DrumSet.bankMSB,
                                     lsb: GM2DrumSet.bankLSB))
        }
    }
}
