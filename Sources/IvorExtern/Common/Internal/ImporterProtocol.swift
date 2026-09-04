// © 2025–2026 John Gary Pusey (see LICENSE.md)

internal import Foundation
internal import IvorModel

internal protocol ImporterProtocol: Sendable {

    // MARK: Internal Instance Properties

    var readableFileFormats: [FileFormat] { get }

    // MARK: Internal Instance Methods

    func read(from file: FileWrapper,
              as fileFormat: FileFormat) throws -> [Work]
}
