internal import Foundation
internal import IvorModel

extension MIDI {
    internal struct Importer: External.Importer {
    }
}

// MARK: -

extension MIDI.Importer {

    // MARK: Internal Instance Properties

    internal var readableFileFormats: [External.FileFormat] {
        [.midi]
    }

    // MARK: Internal Instance Methods

    internal func read(from file: FileWrapper,
                       as fileFormat: External.FileFormat) throws -> [Work] {
        switch fileFormat {
        case .midi:
            guard let data = file.regularFileContents
            else { throw MIDI.Error.parseFailure(nil) }

            let sequence = try MIDI.Parser().parse(data)
            let work = try MIDI.Converter().convert(sequence)

            return [work]

        default:
            throw MIDI.Error.unsupportedFileFormat(fileFormat.displayName)
        }
    }
}

// MARK: - Sendable

extension MIDI.Importer: Sendable {
}
