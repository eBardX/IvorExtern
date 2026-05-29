// © 2025–2026 John Gary Pusey (see LICENSE.md)

internal import Foundation
internal import IvorModel

extension Guido {
    internal struct Exporter: ExporterProtocol {
    }
}

// MARK: -

extension Guido.Exporter {

    // MARK: Internal Instance Properties

    internal var writableFileFormats: [FileFormat] {
        []
    }

    // MARK: Internal Instance Methods

    internal func write(works: [Work],
                        as fileFormat: FileFormat) throws -> FileWrapper {
        throw Guido.Error.unsupportedFileFormat(fileFormat.displayName)
    }
}

// MARK: - Sendable

extension Guido.Exporter: Sendable {
}
