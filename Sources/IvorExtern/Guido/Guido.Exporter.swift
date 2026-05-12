internal import Foundation
internal import IvorModel

extension Guido {
    internal struct Exporter: External.Exporter {
    }
}

// MARK: -

extension Guido.Exporter {

    // MARK: Internal Instance Properties

    internal var writableFileFormats: [External.FileFormat] {
        []
    }

    // MARK: Internal Instance Methods

    internal func write(works: [Work],
                        as fileFormat: External.FileFormat) throws -> FileWrapper {
        throw Guido.Error.unsupportedFileFormat(fileFormat.displayName)
    }
}

// MARK: - Sendable

extension Guido.Exporter: Sendable {
}
