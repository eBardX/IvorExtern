// © 2026 John Gary Pusey (see LICENSE.md)

extension ImportOptions {

    // MARK: Public Nested Types

    /// An import option that a format can use (see ``ImportFileFormat/supportedOptions``).
    public enum Key {
        /// The ``ImportOptions/pedalSimplification`` option.
        case pedalSimplification
    }
}

// MARK: - CaseIterable

extension ImportOptions.Key: CaseIterable {
}

// MARK: - Hashable

extension ImportOptions.Key: Hashable {
}

// MARK: - Sendable

extension ImportOptions.Key: Sendable {
}
