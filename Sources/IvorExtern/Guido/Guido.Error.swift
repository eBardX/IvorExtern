// © 2025–2026 John Gary Pusey (see LICENSE.md)

internal import IvorGuido
internal import IvorTiming
internal import IvorTuning
internal import XestiTools

extension Guido {
    internal enum Error {
        case circularVariableReference(GMNVariable.Name)
        case convertFailure((any EnhancedError)?)
        case formatFailure((any EnhancedError)?)
        case multipleWorksNotSupported
        case noWorksToExport
        case parseFailure((any EnhancedError)?)
        case unrecognizedPitchAccidental(Guido.Pitch.Accidental)
        case unrecognizedPitchName(Guido.Pitch.Name)
        case unrecognizedPitchOctave(Int)
        case unrepresentableDuration(String)
        case unsupportedEvent(Guido.Event)
        case unsupportedFileFormat(String)
        case unsupportedPitchNotation(PitchNotation)
        case unsupportedTimeBasis(TimeBasis)
        case validationFailure([Guido.Validator.Issue])
    }
}

// MARK: - EnhancedError

extension Guido.Error: EnhancedError {
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
        case let .circularVariableReference(name):
            "Circular variable reference: ‘$\(name.stringValue)’"

        case .convertFailure:
            "Unable to convert Guido score to Ivor work"

        case .formatFailure:
            "Unable to format Guido score"

        case .multipleWorksNotSupported:
            "Multiple works are not supported"

        case .noWorksToExport:
            "No works to export"

        case .parseFailure:
            "Unable to parse Guido score"

        case let .unrecognizedPitchAccidental(accidental):
            "Unrecognized Guido pitch accidental: ‘\(accidental)’"

        case let .unrecognizedPitchName(name):
            "Unrecognized Guido pitch name: ‘\(name)’"

        case let .unrecognizedPitchOctave(octave):
            "Unrecognized Guido pitch octave: ‘\(octave)’"

        case let .unrepresentableDuration(description):
            "Unrepresentable duration: ‘\(description)’"

        case let .unsupportedEvent(event):
            "Unsupported event: ‘\(event)’"

        case let .unsupportedFileFormat(fileFormat):
            "Unsupported file format: ‘\(fileFormat)’"

        case let .unsupportedPitchNotation(pitchNotation):
            "Unsupported pitch notation: \(pitchNotation)"

        case let .unsupportedTimeBasis(timeBasis):
            "Unsupported time basis: \(timeBasis)"

        case let .validationFailure(issues):
            "Guido score failed validation: \(issues.map(\.message).joined(separator: "; "))"
        }
    }
}

// MARK: - Sendable

extension Guido.Error: Sendable {
}
