// © 2025–2026 John Gary Pusey (see LICENSE.md)

internal import XestiTools

extension JohnnySonic {
    internal enum Error {
        case convertFailure((any EnhancedError)?)
        case formatFailure((any EnhancedError)?)
        case unsupportedFileFormat(String)
        case unsupportedWorkTimeBasis(String)
    }
}

// MARK: - EnhancedError

extension JohnnySonic.Error: EnhancedError {
    internal var category: Category? {
        Category("IvorExtern")
    }

    internal var cause: (any EnhancedError)? {
        switch self {
        case let .convertFailure(error),
            let .formatFailure(error):
            error

        default:
            nil
        }
    }

    internal var message: String {
        switch self {
        case .convertFailure:
            "Unable to convert Ivor work to JohnnySonic score"

        case .formatFailure:
            "Unable to format JohnnySonic score"

        case let .unsupportedFileFormat(fileFormat):
            "Unsupported file format: ‘\(fileFormat)’"

        case let .unsupportedWorkTimeBasis(timeBasis):
            "Unsupported Ivor work time basis: \(timeBasis)"
        }
    }
}

// MARK: - Sendable

extension JohnnySonic.Error: Sendable {
}
