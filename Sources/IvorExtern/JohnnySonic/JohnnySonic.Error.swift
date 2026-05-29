// © 2025–2026 John Gary Pusey (see LICENSE.md)

internal import IvorTiming
internal import IvorTuning
internal import XestiTools

extension JohnnySonic {
    internal enum Error {
        case convertFailure((any EnhancedError)?)
        case formatFailure((any EnhancedError)?)
        case multipleWorksNotSupported
        case unsupportedFileFormat(String)
        case unsupportedPitchNotation(PitchNotation)
        case unsupportedTimeBasis(TimeBasis)
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

        case .multipleWorksNotSupported:
            "Multiple works are not supported"

        case let .unsupportedFileFormat(fileFormat):
            "Unsupported file format: ‘\(fileFormat)’"

        case let .unsupportedPitchNotation(pitchNotation):
            "Unsupported pitch notation: \(pitchNotation)"

        case let .unsupportedTimeBasis(timeBasis):
            "Unsupported time basis: \(timeBasis)"
        }
    }
}

// MARK: - Sendable

extension JohnnySonic.Error: Sendable {
}
