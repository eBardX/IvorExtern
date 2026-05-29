// © 2025–2026 John Gary Pusey (see LICENSE.md)

internal import Foundation
internal import IvorModel

internal protocol Exportable<Exporter>: Sendable {
    associatedtype Exporter: ExporterProtocol

    var exporter: Exporter { get }
}

internal protocol ExporterProtocol: Sendable {
    var writableFileFormats: [FileFormat] { get }

    func write(works: [Work],
               as fileFormat: FileFormat) throws -> FileWrapper
}
