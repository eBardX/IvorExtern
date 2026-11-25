// © 2026 John Gary Pusey (see LICENSE.md)

public import IvorModel

/// Options that adjust how an ``ExportFileFormat`` writes works.
///
/// The defaults (``default``) write a file just as an export without options does. A format
/// ignores any option it doesn’t use; ``ExportFileFormat/supportedOptions`` lists the ones it
/// does.
public struct ExportOptions {

    // MARK: Public Initializers

    /// Creates export options.
    ///
    /// - Parameter fermataMode:    How a format that writes sound renders fermata holds and
    ///                             caesura pauses. Defaults to
    ///                             ``IvorModel/RenderingOptions/FermataMode/tempoChanges``.
    /// - Parameter midi:           The options for exporting a Standard MIDI File.
    public init(fermataMode: RenderingOptions.FermataMode = .tempoChanges,
                midi: MIDIExportOptions = MIDIExportOptions()) {
        self.fermataMode = fermataMode
        self.midi = midi
    }

    // MARK: Public Instance Properties

    /// How a format that writes sound — a Standard MIDI File or a JohnnySonic score — renders
    /// fermata holds and caesura pauses (see ``IvorModel/Work/rendered(options:)``).
    ///
    /// The default, ``IvorModel/RenderingOptions/FermataMode/tempoChanges``, slows the tempo
    /// over each held span, which keeps the bar grid.
    public var fermataMode: RenderingOptions.FermataMode

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
