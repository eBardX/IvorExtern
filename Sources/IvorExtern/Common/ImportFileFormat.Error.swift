// © 2026 John Gary Pusey (see LICENSE.md)

public import XestiTools

extension ImportFileFormat {

    /// An error that occurs when reading works from a file in an import
    /// format.
    public enum Error {
        /// The works failed to be read, with an optional underlying error.
        case readFailure((any EnhancedError)?)
    }
}

// MARK: - EnhancedError

extension ImportFileFormat.Error: EnhancedError {
    /// The error category identifying the source module.
    public var category: Category? {
        Category("IvorExtern")
    }

    /// The underlying error that caused this error, if any.
    public var cause: (any EnhancedError)? {
        switch self {
        case let .readFailure(error):
            error
        }
    }

    /// A human-readable description of this error.
    public var message: String {
        switch self {
        case .readFailure:
            "Unable to read works from file"
        }
    }
}

// MARK: - Sendable

extension ImportFileFormat.Error: Sendable {
}
