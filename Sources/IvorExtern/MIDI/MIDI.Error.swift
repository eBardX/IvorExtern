// © 2025–2026 John Gary Pusey (see LICENSE.md)

internal import IvorMIDI
internal import IvorTiming
internal import IvorTuning
internal import XestiTools

extension MIDI {
    internal enum Error {
        case convertFailure((any EnhancedError)?)
        case emptyBeatMap
        case formatFailure((any EnhancedError)?)
        case invalidBeatDuration(BeatDuration)
        case invalidClockRate(UInt)
        case invalidEventTime(EventTime)
        case invalidNoteNumber(IvorTuning.NoteNumber)
        case multipleWorksNotSupported
        case noWorksToExport
        case parseFailure((any EnhancedError)?)
        case tooManyParts(Int)
        case unexpectedNoteOff(channel: Channel, key: NoteNumber, time: EventTime)
        case unpairedNoteOn(channel: Channel, key: NoteNumber, time: EventTime)
        case unsupportedDivision(Division)
        case unsupportedFileFormat(String)
        case unsupportedPitchNotation(PitchNotation)
        case unsupportedTimeBasis(TimeBasis)
        case validationFailure([MIDI.Validator.Issue])
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

        case let .invalidBeatDuration(beatDuration):
            "Invalid beat duration: \(beatDuration)"

        case let .invalidClockRate(clockRate):
            "Invalid SMF time signature clock rate: \(clockRate)"

        case let .invalidEventTime(eventTime):
            "Invalid SMF event time: \(eventTime)"

        case let .invalidNoteNumber(noteNumber):
            "Invalid note number: \(noteNumber)"

        case .multipleWorksNotSupported:
            "Multiple works are not supported"

        case .noWorksToExport:
            "No works to export"

        case .parseFailure:
            "Unable to parse SMF sequence"

        case let .tooManyParts(count):
            "Too many parts to export: \(count) (MIDI supports a maximum of 16 channels)"

        case let .unexpectedNoteOff(channel, key, time):
            "Unexpected note-off on channel \(channel.uintValue) for key \(key.uintValue) at time \(time.uintValue) with no matching note-on"

        case let .unpairedNoteOn(channel, key, time):
            "Unpaired note-on on channel \(channel.uintValue) for key \(key.uintValue) at time \(time.uintValue) with no matching note-off"

        case let .unsupportedDivision(division):
            "Unsupported SMF division: ‘\(division)’"

        case let .unsupportedFileFormat(fileFormat):
            "Unsupported file format: ‘\(fileFormat)’"

        case let .unsupportedPitchNotation(pitchNotation):
            "Unsupported pitch notation: \(pitchNotation)"

        case let .unsupportedTimeBasis(timeBasis):
            "Unsupported time basis: \(timeBasis)"

        case let .validationFailure(issues):
            "SMF sequence failed validation: \(issues.map(\.message).joined(separator: "; "))"
        }
    }
}

// MARK: - Sendable

extension MIDI.Error: Sendable {
}
