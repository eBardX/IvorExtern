// © 2025–2026 John Gary Pusey (see LICENSE.md)

internal import IvorGuido
internal import XestiTools

extension Guido {
    internal enum Error {
        case convertFailure((any EnhancedError)?)
        case incompleteDuration(Guido.Duration)
        case nestedChord
        case parseFailure((any EnhancedError)?)
        case unrecognizedPitchAccidental(Guido.Pitch.Accidental)
        case unrecognizedPitchName(Guido.Pitch.Name)
        case unrecognizedPitchOctave(Guido.Pitch.Octave)
        case unsupportedFileFormat(String)
        case unsupportedSymbol(Guido.Symbol)
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
            let .parseFailure(error):
            error

        default:
            nil
        }
    }

    internal var message: String {
        switch self {
        case .convertFailure:
            "Unable to convert Guido score to Ivor work"

        case let .incompleteDuration(duration):
            "Incomplete Guido duration: ‘\(duration)’"

        case .nestedChord:
            "Nested chords are disallowed"

        case .parseFailure:
            "Unable to parse Guido score"

        case let .unrecognizedPitchAccidental(accidental):
            "Unrecognized Guido pitch accidental: ‘\(accidental)’"

        case let .unrecognizedPitchName(name):
            "Unrecognized Guido pitch name: ‘\(name)’"

        case let .unrecognizedPitchOctave(octave):
            "Unrecognized Guido pitch octave: ‘\(octave)’"

        case let .unsupportedFileFormat(fileFormat):
            "Unsupported file format: ‘\(fileFormat)’"

        case let .unsupportedSymbol(symbol):
            "Unsupported symbol: ‘\(symbol)’"
        }
    }
}

// MARK: - Sendable

extension Guido.Error: Sendable {
}
