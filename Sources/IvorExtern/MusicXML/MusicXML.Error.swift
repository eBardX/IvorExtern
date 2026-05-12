internal import IvorMusicXML
internal import XestiTools

extension MusicXML {
    internal enum Error {
        case convertFailure((any EnhancedError)?)
        case invalidRootFileMediaType(String)
        case noRootFileFound
        case parseFailure((any EnhancedError)?)
        case partMismatch
        case unrecognizedPitchAccidental(MusicXML.Pitch.Accidental)
        case unrecognizedPitchLetter(MusicXML.Pitch.Letter)
        case unrecognizedPitchOctave(MusicXML.Pitch.Octave)
        case unsupportedFileFormat(String)
        case unsupportedScoreFormat(String)
    }
}

// MARK: - EnhancedError

extension MusicXML.Error: EnhancedError {
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
            "Unable to convert MusicXML score to Ivor work"

        case let .invalidRootFileMediaType(mediaType):
            "Invalid root file media type: \(mediaType)"

        case .noRootFileFound:
            "No root files found in container"

        case .parseFailure:
            "Unable to parse MusicXML score"

        case .partMismatch:
            "Number of MusicXML score parts does not match number of MusicXML parts"

        case let .unrecognizedPitchAccidental(accidental):
            "Unrecognized MusicXML pitch accidental: \(accidental)"

        case let .unrecognizedPitchLetter(letter):
            "Unrecognized MusicXML pitch letter: ‘\(letter)’"

        case let .unrecognizedPitchOctave(octave):
            "Unrecognized MusicXML pitch octave: ‘\(octave)’"

        case let .unsupportedFileFormat(fileFormat):
            "Unsupported file format: ‘\(fileFormat)’"

        case let .unsupportedScoreFormat(scoreFormat):
            "Unsupported MusicXML score format: ‘\(scoreFormat)’"
        }
    }
}

// MARK: - Sendable

extension MusicXML.Error: Sendable {
}
