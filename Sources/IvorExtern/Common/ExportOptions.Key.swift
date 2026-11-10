// © 2026 John Gary Pusey (see LICENSE.md)

extension ExportOptions {

    // MARK: Public Nested Types

    /// An export option that a format can use (see ``ExportFileFormat/supportedOptions``).
    public enum Key {
        /// ``MIDIExportOptions/ticksPerQuarterNote``, for a beat-time work.
        case midiTicksPerQuarterNote

        /// ``MIDIExportOptions/timeCodeFrameRate`` and ``MIDIExportOptions/ticksPerFrame``, for
        /// a wall-time work.
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
