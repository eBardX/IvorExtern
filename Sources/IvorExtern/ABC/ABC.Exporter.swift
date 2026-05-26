// © 2025–2026 John Gary Pusey (see LICENSE.md)

internal import Foundation
internal import IvorModel

extension ABC {
    internal struct Exporter: External.Exporter {
    }
}

// MARK: -

extension ABC.Exporter {

    // MARK: Public Instance Properties

    internal var writableFileFormats: [External.FileFormat] {
        []
    }

    // MARK: Public Instance Methods

    internal func write(works: [Work],
                        as fileFormat: External.FileFormat) throws -> FileWrapper {
        throw ABC.Error.unsupportedFileFormat(fileFormat.displayName)
    }
}

// MARK: - Sendable

extension ABC.Exporter: Sendable {
}
