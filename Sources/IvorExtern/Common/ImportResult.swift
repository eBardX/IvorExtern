// © 2026 John Gary Pusey (see LICENSE.md)

public import IvorModel

/// The works read from a file, with what couldn’t be carried over exactly (see
/// ``ImportFileFormat/read(from:options:)``).
public struct ImportResult {

    // MARK: Public Instance Properties

    /// What was dropped or approximated while reading, one warning per kind of loss in each
    /// work.
    public let warnings: [ExternWarning]

    /// The works read.
    public let works: [Work]

    // MARK: Internal Initializers

    internal init(works: [Work],
                  warnings: [ExternWarning]) {
        self.warnings = warnings
        self.works = works
    }
}

// MARK: - Sendable

extension ImportResult: Sendable {
}
