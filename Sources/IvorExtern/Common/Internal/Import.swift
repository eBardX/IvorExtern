// © 2025–2026 John Gary Pusey (see LICENSE.md)

internal import Foundation
internal import IvorModel

internal protocol Importable<Importer>: Sendable {
    associatedtype Importer: ImporterProtocol

    var importer: Importer { get }
}

internal protocol ImporterProtocol: Sendable {
    var readableFileFormats: [FileFormat] { get }

    func read(from file: FileWrapper,
              as fileFormat: FileFormat) throws -> [Work]
}
