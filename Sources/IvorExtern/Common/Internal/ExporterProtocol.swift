// © 2025–2026 John Gary Pusey (see LICENSE.md)

internal import Foundation
internal import IvorModel

internal protocol ExporterProtocol: Sendable {

    // MARK: Internal Instance Properties

    var writableFileFormats: [FileFormat] { get }

    // MARK: Internal Instance Methods

    func write(works: [Work],
               as fileFormat: FileFormat) throws -> FileWrapper
}
