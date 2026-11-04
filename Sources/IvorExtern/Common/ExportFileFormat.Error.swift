// © 2026 John Gary Pusey (see LICENSE.md)

public import XestiTools

extension ExportFileFormat {

    // MARK: Public Nested Types

    /// An error that occurs when writing works to a file in an export
    /// format.
    public enum Error {
        /// A failure to write the works, with an optional underlying error.
        case writeFailure((any EnhancedError)?)
    }
}

// MARK: - EnhancedError

extension ExportFileFormat.Error: EnhancedError {

    // MARK: Public Instance Properties

    /// The error category identifying the source module.
    public var category: Category? {
        Category("IvorExtern")
    }

    /// The underlying error that caused this error, if any.
    public var cause: (any EnhancedError)? {
        switch self {
        case let .writeFailure(error):
            error
        }
    }

    /// A human-readable description of this error.
    public var message: String {
        switch self {
        case .writeFailure:
            "Unable to write works to file"
        }
    }
}

// MARK: - Sendable

extension ExportFileFormat.Error: Sendable {
}
