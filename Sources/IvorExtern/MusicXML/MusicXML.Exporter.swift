// © 2025–2026 John Gary Pusey (see LICENSE.md)

internal import Foundation
internal import IvorModel

extension MusicXML {
    internal struct Exporter: ExporterProtocol {
    }
}

// MARK: -

extension MusicXML.Exporter {

    // MARK: Internal Instance Properties

    internal var writableFileFormats: [FileFormat] {
        []
    }

    // MARK: Internal Instance Methods

    internal func write(works: [Work],
                        as fileFormat: FileFormat) throws -> FileWrapper {
        throw MusicXML.Error.unsupportedFileFormat(fileFormat.displayName)
    }
}

// MARK: - Sendable

extension MusicXML.Exporter: Sendable {
}
