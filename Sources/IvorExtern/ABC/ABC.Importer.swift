// © 2025–2026 John Gary Pusey (see LICENSE.md)

internal import Foundation
internal import IvorModel

extension ABC {
    internal struct Importer: External.Importer {
    }
}

// MARK: -

extension ABC.Importer {

    // MARK: Public Instance Properties

    internal var readableFileFormats: [External.FileFormat] {
        [.abc]
    }

    // MARK: Public Instance Methods

    internal func read(from file: FileWrapper,
                       as fileFormat: External.FileFormat) throws -> [Work] {
        switch fileFormat {
        case .abc:
            guard let data = file.regularFileContents
            else { throw ABC.Error.parseFailure(nil) }

            let tunebook = try ABC.Parser().parse(data)

            return try ABC.Converter().convert(tunebook)

        default:
            throw ABC.Error.unsupportedFileFormat(fileFormat.displayName)
        }
    }
}

// MARK: - Sendable

extension ABC.Importer: Sendable {
}
