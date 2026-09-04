// © 2025–2026 John Gary Pusey (see LICENSE.md)

internal import IvorABC
internal import IvorTiming
internal import IvorTuning
internal import XestiTools

extension ABC {

    // MARK: Internal Nested Types

    internal enum Error {
        case convertFailure((any EnhancedError)?)
        case formatFailure((any EnhancedError)?)
        case noWorksToExport
        case parseFailure((any EnhancedError)?)
        case unbalancedRepeat(String)
        case undefinedPart(String)
        case unrecognizedPitchAccidental(ABC.Pitch.Accidental)
        case unrecognizedPitchLetter(ABC.Pitch.Letter)
        case unrecognizedPitchOctave(ABC.Pitch.Octave)
        case unrepresentableDuration(String)
        case unrepresentablePitch(String)
        case unresolvableMacro(String)
        case unsupportedFileFormat(String)
        case unsupportedPitchNotation(PitchNotation)
        case unsupportedTimeBasis(TimeBasis)
        case validationFailure([ABC.Validator.Issue])
    }
}

// MARK: - EnhancedError

extension ABC.Error: EnhancedError {

    // MARK: Internal Instance Properties

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
            "Unable to convert ABC file to Ivor work"

        case .formatFailure:
            "Unable to format ABC tunebook"

        case .noWorksToExport:
            "No works to export"

        case .parseFailure:
            "Unable to parse ABC file"

        case let .unbalancedRepeat(description):
            "Unbalanced repeat: ‘\(description)’"

        case let .undefinedPart(description):
            "Undefined part: ‘\(description)’"

        case let .unrecognizedPitchAccidental(accidental):
            "Unrecognized ABC pitch accidental: ‘\(accidental)’"

        case let .unrecognizedPitchLetter(letter):
            "Unrecognized ABC pitch letter: ‘\(letter)’"

        case let .unrecognizedPitchOctave(octave):
            "Unrecognized ABC pitch octave: ‘\(octave)’"

        case let .unrepresentableDuration(description):
            "Unrepresentable duration: ‘\(description)’"

        case let .unrepresentablePitch(description):
            "Unrepresentable pitch: ‘\(description)’"

        case let .unresolvableMacro(description):
            "Unresolvable macro: ‘\(description)’"

        case let .unsupportedFileFormat(fileFormat):
            "Unsupported file format: ‘\(fileFormat)’"

        case let .unsupportedPitchNotation(pitchNotation):
            "Unsupported pitch notation: \(pitchNotation)"

        case let .unsupportedTimeBasis(timeBasis):
            "Unsupported time basis: \(timeBasis)"

        case let .validationFailure(issues):
            "ABC tunebook failed validation: \(issues.map(\.message).joined(separator: "; "))"
        }
    }
}

// MARK: - Sendable

extension ABC.Error: Sendable {
}
