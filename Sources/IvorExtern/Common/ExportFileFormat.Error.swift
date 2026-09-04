// © 2026 John Gary Pusey (see LICENSE.md)

public import XestiTools

extension ExportFileFormat {

    /// An error that occurs when writing works to a file in an export
    /// format.
    public enum Error {
        /// The works failed to be written, with an optional underlying
        /// error.
        case writeFailure((any EnhancedError)?)
    }
}

// MARK: - EnhancedError

extension ExportFileFormat.Error: EnhancedError {
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
