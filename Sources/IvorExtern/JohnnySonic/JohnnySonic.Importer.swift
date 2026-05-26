// © 2025–2026 John Gary Pusey (see LICENSE.md)

internal import Foundation
internal import IvorModel

extension JohnnySonic {
    internal struct Importer: External.Importer {
    }
}

// MARK: -

extension JohnnySonic.Importer {

    // MARK: Internal Instance Properties

    internal var readableFileFormats: [External.FileFormat] {
        []
    }

    // MARK: Internal Instance Methods

    internal func read(from file: FileWrapper,
                       as fileFormat: External.FileFormat) throws -> [Work] {
        throw JohnnySonic.Error.unsupportedFileFormat(fileFormat.displayName)
    }
}

// MARK: - Sendable

extension JohnnySonic.Importer: Sendable {
}
