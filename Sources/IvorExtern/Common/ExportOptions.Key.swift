// © 2026 John Gary Pusey (see LICENSE.md)

extension ExportOptions {

    // MARK: Public Nested Types

    /// An export option that a format can use (see ``ExportFileFormat/supportedOptions``).
    public enum Key {
        /// The ``MIDIExportOptions/ticksPerQuarterNote`` option, for a beat-time work.
        case midiTicksPerQuarterNote

        /// The ``MIDIExportOptions/timeCodeFrameRate`` and ``MIDIExportOptions/ticksPerFrame``
        /// options, for a wall-time work.
        case midiTimeCode
    }
}

// MARK: - CaseIterable

extension ExportOptions.Key: CaseIterable {
}

// MARK: - Hashable

extension ExportOptions.Key: Hashable {
}

// MARK: - Sendable

extension ExportOptions.Key: Sendable {
}
