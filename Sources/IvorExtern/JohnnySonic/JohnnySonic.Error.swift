// © 2025–2026 John Gary Pusey (see LICENSE.md)

internal import IvorJohnnySonic
internal import IvorTiming
internal import IvorTuning
internal import XestiTools

extension JohnnySonic {
    internal enum Error {
        case convertFailure((any EnhancedError)?)
        case formatFailure((any EnhancedError)?)
        case inconsistentPitchNotation
        case multipleWorksNotSupported
        case noWorksToExport
        case parseFailure((any EnhancedError)?)
        case unsupportedFileFormat(String)
        case unsupportedPitchNotation(PitchNotation)
        case unsupportedTimeBasis(TimeBasis)
        case validationFailure([JohnnySonic.Validator.Issue])
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
             let .formatFailure(error),
             let .parseFailure(error):
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

        case .inconsistentPitchNotation:
            "Score contains both absolute and keyboard pitch notations"

        case .multipleWorksNotSupported:
            "Multiple works are not supported"

        case .noWorksToExport:
            "No works to export"

        case .parseFailure:
            "Unable to parse JohnnySonic score"

        case let .unsupportedFileFormat(fileFormat):
            "Unsupported file format: ‘\(fileFormat)’"

        case let .unsupportedPitchNotation(pitchNotation):
            "Unsupported pitch notation: \(pitchNotation)"

        case let .unsupportedTimeBasis(timeBasis):
            "Unsupported time basis: \(timeBasis)"

        case let .validationFailure(issues):
            "JohnnySonic score failed validation: \(issues.map(\.message).joined(separator: "; "))"
        }
    }
}

// MARK: - Sendable

extension JohnnySonic.Error: Sendable {
}
