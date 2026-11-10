// © 2026 John Gary Pusey (see LICENSE.md)

public import IvorSMPTE

private import IvorSMF

/// Options for exporting a work as a Standard MIDI File.
///
/// A work imported from a file with a time-code division is written back with that division,
/// whatever these options say.
public struct MIDIExportOptions {

    // MARK: Public Initializers

    /// Creates MIDI export options.
    ///
    /// - Parameter ticksPerQuarterNote:    The ticks per quarter note for a beat-time work.
    /// - Parameter timeCodeFrameRate:      The time-code frame rate for a wall-time work.
    /// - Parameter ticksPerFrame:          The ticks per frame for a wall-time work.
    public init(ticksPerQuarterNote: UInt = 480,
                timeCodeFrameRate: SMPTEFrameRate = .fps25,
                ticksPerFrame: UInt = 40) {
        self.ticksPerFrame = ticksPerFrame
        self.ticksPerQuarterNote = ticksPerQuarterNote
        self.timeCodeFrameRate = timeCodeFrameRate
    }

    // MARK: Public Instance Properties

    /// The ticks per frame of the time-code division that a wall-time work is written with.
    ///
    /// It must be in ``ticksPerFrameRange``. The default is 40, which at the default frame rate
    /// is one tick per millisecond.
    public var ticksPerFrame: UInt

    /// The ticks per quarter note of the metrical division that a beat-time work is written with.
    ///
    /// It must be in ``ticksPerQuarterNoteRange``. The default is 480.
    public var ticksPerQuarterNote: UInt

    /// The frame rate of the time-code division that a wall-time work is written with.
    ///
    /// It must be one of ``supportedFrameRates``. The default is 25 frames per second.
    public var timeCodeFrameRate: SMPTEFrameRate
}

// MARK: -

extension MIDIExportOptions {

    // MARK: Public Type Properties

    /// The frame rates that a Standard MIDI File’s time-code division can use.
    public static let supportedFrameRates = SMPTEFrameRate.allCases.filter { SMFTimeCode.supports($0) }

    /// The range of valid ticks per frame.
    public static let ticksPerFrameRange: ClosedRange<UInt> = 1...255

    /// The range of valid ticks per quarter note.
    public static let ticksPerQuarterNoteRange: ClosedRange<UInt> = 1...32_767
}

// MARK: - Equatable

extension MIDIExportOptions: Equatable {
}

// MARK: - Sendable

extension MIDIExportOptions: Sendable {
}
