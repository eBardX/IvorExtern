// © 2025–2026 John Gary Pusey (see LICENSE.md)

internal import Foundation
internal import IvorModel

extension External {

    // MARK: Internal Nested Types

    internal protocol Importable<Importer>: Sendable {
        associatedtype Importer: External.Importer

        var importer: Importer { get }
    }

    internal protocol Importer: Sendable {
        var readableFileFormats: [FileFormat] { get }

        func read(from file: FileWrapper,
                  as fileFormat: FileFormat) throws -> [Work]
    }
}
