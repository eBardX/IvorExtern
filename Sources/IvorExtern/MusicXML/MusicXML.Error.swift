// © 2025–2026 John Gary Pusey (see LICENSE.md)

internal import IvorMusicXML
internal import IvorTiming
internal import IvorTuning
internal import XestiTools

extension MusicXML {
    internal enum Error {
        case convertFailure((any EnhancedError)?)
        case durationBeforeDivisions(String)
        case formatFailure((any EnhancedError)?)
        case invalidRootFileMediaType(String)
        case multipleWorksNotSupported
        case noRootFileFound
        case noWorksToExport
        case parseFailure((any EnhancedError)?)
        case partMismatch
        case unbalancedBackup(String)
        case unbalancedRepeat(String)
        case unexpandableMeasure(String)
        case unrecognizedPitchAccidental(Double)
        case unrecognizedPitchOctave(Int)
        case unrepresentablePitch(String)
        case unresolvableDuration(String)
        case unsupportedFileFormat(String)
        case unsupportedPitchNotation(PitchNotation)
        case unsupportedScoreFormat(String)
        case unsupportedTimeBasis(TimeBasis)
        case validationFailure([MusicXML.Validator.Issue])
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
            "Unable to convert MusicXML score to Ivor work"

        case let .durationBeforeDivisions(description):
            "Durational element before any divisions: ‘\(description)’"

        case .formatFailure:
            "Unable to format MusicXML score"

        case let .invalidRootFileMediaType(mediaType):
            "Invalid root file media type: \(mediaType)"

        case .multipleWorksNotSupported:
            "Multiple works are not supported"

        case .noRootFileFound:
            "No root files found in container"

        case .noWorksToExport:
            "No works to export"

        case .parseFailure:
            "Unable to parse MusicXML score"

        case .partMismatch:
            "Number of MusicXML score parts does not match number of MusicXML parts"

        case let .unbalancedBackup(description):
            "Unbalanced backup: ‘\(description)’"

        case let .unbalancedRepeat(description):
            "Unbalanced repeat structure: ‘\(description)’"

        case let .unexpandableMeasure(description):
            "Unexpandable measure span: ‘\(description)’"

        case let .unrecognizedPitchAccidental(alter):
            "Unrecognized MusicXML pitch accidental: ‘\(alter)’"

        case let .unrecognizedPitchOctave(octave):
            "Unrecognized MusicXML pitch octave: ‘\(octave)’"

        case let .unrepresentablePitch(description):
            "Transposed pitch out of range: ‘\(description)’"

        case let .unresolvableDuration(description):
            "Unresolvable duration: ‘\(description)’"

        case let .unsupportedFileFormat(fileFormat):
            "Unsupported file format: ‘\(fileFormat)’"

        case let .unsupportedPitchNotation(pitchNotation):
            "Unsupported pitch notation: \(pitchNotation)"

        case let .unsupportedScoreFormat(scoreFormat):
            "Unsupported MusicXML score format: ‘\(scoreFormat)’"

        case let .unsupportedTimeBasis(timeBasis):
            "Unsupported time basis: \(timeBasis)"

        case let .validationFailure(issues):
            "MusicXML score failed validation: \(issues.map(\.message).joined(separator: "; "))"
        }
    }
}

// MARK: - Sendable

extension MusicXML.Error: Sendable {
}
