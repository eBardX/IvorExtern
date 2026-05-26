// © 2025–2026 John Gary Pusey (see LICENSE.md)

internal import Foundation
internal import IvorModel

extension Guido {
    internal struct Importer: External.Importer {
    }
}

// MARK: -

extension Guido.Importer {

    // MARK: Internal Instance Properties

    internal var readableFileFormats: [External.FileFormat] {
        [.gmn]
    }

    // MARK: Internal Instance Methods

    internal func read(from file: FileWrapper,
                       as fileFormat: External.FileFormat) throws -> [Work] {
        switch fileFormat {
        case .gmn:
            guard let data = file.regularFileContents
            else { throw Guido.Error.parseFailure(nil) }

            let score = try Guido.Parser().parse(data)
            let work = try Guido.Converter().convert(score)

            return [work]

        default:
            throw Guido.Error.unsupportedFileFormat(fileFormat.displayName)
        }
    }
}

// MARK: - Sendable

extension Guido.Importer: Sendable {
}
