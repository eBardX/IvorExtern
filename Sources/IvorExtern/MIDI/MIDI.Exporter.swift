// © 2025–2026 John Gary Pusey (see LICENSE.md)

internal import Foundation
internal import IvorModel

extension MIDI {
    internal struct Exporter: External.Exporter {
    }
}

// MARK: -

extension MIDI.Exporter {

    // MARK: Internal Instance Properties

    internal var writableFileFormats: [External.FileFormat] {
        [.midi]
    }

    // MARK: Internal Instance Methods

    internal func write(works: [Work],
                        as fileFormat: External.FileFormat) throws -> FileWrapper {
        switch fileFormat {
        case .midi:
            guard let work = works.first,
                  works.count == 1
            else { throw MIDI.Error.formatFailure(nil) }

            let sequence = try MIDI.Converter().convert(work)
            let data = try MIDI.Formatter().format(sequence)

            return FileWrapper(regularFileWithContents: data)

        default:
            throw MIDI.Error.unsupportedFileFormat(fileFormat.displayName)
        }
    }
}

// MARK: - Sendable

extension MIDI.Exporter: Sendable {
}
