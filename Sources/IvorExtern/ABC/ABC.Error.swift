// © 2025–2026 John Gary Pusey (see LICENSE.md)

internal import IvorABC
internal import XestiTools

extension ABC {
    internal enum Error {
        case convertFailure((any EnhancedError)?)
        case parseFailure((any EnhancedError)?)
        case unrecognizedPitchAccidental(ABC.Pitch.Accidental)
        case unrecognizedPitchLetter(ABC.Pitch.Letter)
        case unrecognizedPitchOctave(ABC.Pitch.Octave)
        case unsupportedFileFormat(String)
    }
}

// MARK: - EnhancedError

extension ABC.Error: EnhancedError {
    internal var category: Category? {
        Category("IvorExtern")
    }

    internal var cause: (any EnhancedError)? {
        switch self {
        case let .convertFailure(error),
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

        case .parseFailure:
            "Unable to parse ABC file"

        case let .unrecognizedPitchAccidental(accidental):
            "Unrecognized ABC pitch accidental: ‘\(accidental)’"

        case let .unrecognizedPitchLetter(letter):
            "Unrecognized ABC pitch letter: ‘\(letter)’"

        case let .unrecognizedPitchOctave(octave):
            "Unrecognized ABC pitch octave: ‘\(octave)’"

        case let .unsupportedFileFormat(fileFormat):
            "Unsupported file format: ‘\(fileFormat)’"
        }
    }
}

// MARK: - Sendable

extension ABC.Error: Sendable {
}
