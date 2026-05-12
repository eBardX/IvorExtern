internal import XestiTools

extension MIDI {
    internal enum Error {
        case convertFailure((any EnhancedError)?)
        case emptyBeatMap
        case formatFailure((any EnhancedError)?)
        case invalidClockRate(UInt)
        case invalidEventTime(EventTime)
        case parseFailure((any EnhancedError)?)
        case unsupportedFileFormat(String)
        case unsupportedDivision(Division)
    }
}

// MARK: - EnhancedError

extension MIDI.Error: EnhancedError {
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
            "Unable to convert Ivor work to SMF sequence"

        case .emptyBeatMap:
            "Empty beat map"

        case .formatFailure:
            "Unable to format SMF sequence"

        case let .invalidClockRate(clockRate):
            "Invalid SMF time signature clock rate: \(clockRate)"

        case let .invalidEventTime(eventTime):
            "Invalid SMF event time: \(eventTime)"

        case .parseFailure:
            "Unable to parse SMF sequence"

        case let .unsupportedFileFormat(fileFormat):
            "Unsupported file format: ‘\(fileFormat)’"

        case let .unsupportedDivision(division):
            "Unsupported SMF division: ‘\(division)’"
        }
    }
}

// MARK: - Sendable

extension MIDI.Error: Sendable {
}
