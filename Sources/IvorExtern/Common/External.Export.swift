// © 2025–2026 John Gary Pusey (see LICENSE.md)

internal import Foundation
internal import IvorModel

extension External {

    // MARK: Internal Nested Types

    internal protocol Exportable<Exporter>: Sendable {
        associatedtype Exporter: External.Exporter

        var exporter: Exporter { get }
    }

    internal protocol Exporter: Sendable {
        var writableFileFormats: [FileFormat] { get }

        func write(works: [Work],
                   as fileFormat: FileFormat) throws -> FileWrapper
    }
}
