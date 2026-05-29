// © 2025–2026 John Gary Pusey (see LICENSE.md)

internal import Foundation
internal import IvorModel

extension JohnnySonic {
    internal struct Exporter: ExporterProtocol {
    }
}

// MARK: -

extension JohnnySonic.Exporter {

    // MARK: Internal Instance Properties

    internal var writableFileFormats: [FileFormat] {
        [.dkm]
    }

    // MARK: Internal Instance Methods

    internal func write(works: [Work],
                        as fileFormat: FileFormat) throws -> FileWrapper {
        switch fileFormat {
        case .dkm:
            guard let work = works.first,
                  works.count == 1
            else { throw JohnnySonic.Error.formatFailure(nil) }

            let score = try JohnnySonic.Converter().convert(work)
            let data = try JohnnySonic.Formatter().format(score)

            return FileWrapper(regularFileWithContents: data)

        default:
            throw JohnnySonic.Error.unsupportedFileFormat(fileFormat.displayName)
        }
    }
}

// MARK: - Sendable

extension JohnnySonic.Exporter: Sendable {
}
