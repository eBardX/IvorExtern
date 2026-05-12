internal import Foundation
internal import IvorModel

extension MusicXML {
    internal struct Exporter: External.Exporter {
    }
}

// MARK: -

extension MusicXML.Exporter {

    // MARK: Internal Instance Properties

    internal var writableFileFormats: [External.FileFormat] {
        []
    }

    // MARK: Internal Instance Methods

    internal func write(works: [Work],
                        as fileFormat: External.FileFormat) throws -> FileWrapper {
        throw MusicXML.Error.unsupportedFileFormat(fileFormat.displayName)
    }
}

// MARK: - Sendable

extension MusicXML.Exporter: Sendable {
}
