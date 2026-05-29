// © 2025–2026 John Gary Pusey (see LICENSE.md)

internal import Foundation
internal import IvorModel

extension JohnnySonic {
    internal struct Importer: ImporterProtocol {
    }
}

// MARK: -

extension JohnnySonic.Importer {

    // MARK: Internal Instance Properties

    internal var readableFileFormats: [FileFormat] {
        []
    }

    // MARK: Internal Instance Methods

    internal func read(from file: FileWrapper,
                       as fileFormat: FileFormat) throws -> [Work] {
        throw JohnnySonic.Error.unsupportedFileFormat(fileFormat.displayName)
    }
}

// MARK: - Sendable

extension JohnnySonic.Importer: Sendable {
}
