// © 2026 John Gary Pusey (see LICENSE.md)

/// Options that adjust how an ``ExportFileFormat`` writes works.
///
/// The defaults (``default``) write a file just as an export without options does. A format
/// ignores any option it doesn’t use; ``ExportFileFormat/supportedOptions`` lists the ones it
/// does.
public struct ExportOptions {

    // MARK: Public Initializers

    /// Creates export options.
    ///
    /// - Parameter midi:   The options for exporting a Standard MIDI File.
    public init(midi: MIDIExportOptions = MIDIExportOptions()) {
        self.midi = midi
    }

    // MARK: Public Instance Properties

    /// The options for exporting a Standard MIDI File.
    public var midi: MIDIExportOptions
}

// MARK: -

extension ExportOptions {

    // MARK: Public Type Properties

    /// The default export options, which change nothing.
    public static let `default` = Self()
}

// MARK: - Equatable

extension ExportOptions: Equatable {
}

// MARK: - Sendable

extension ExportOptions: Sendable {
}
