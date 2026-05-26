// © 2025–2026 John Gary Pusey (see LICENSE.md)

internal import Foundation
internal import IvorModel

private import IvorMusicXML
private import XestiTools

extension MusicXML {
    internal struct Importer: External.Importer {
    }
}

// MARK: -

extension MusicXML.Importer {

    // MARK: Internal Instance Properties

    internal var readableFileFormats: [External.FileFormat] {
        [.mxl,
         .musicXML]
    }

    // MARK: Internal Instance Methods

    internal func read(from file: FileWrapper,
                       as fileFormat: External.FileFormat) throws -> [Work] {
        switch fileFormat {
        case .mxl:
            return try _read(file,
                             compressed: true)

        case .musicXML:
            return try _read(file,
                             compressed: false)

        default:
            throw MusicXML.Error.unsupportedFileFormat(fileFormat.displayName)
        }
    }

    // MARK: Private Instance Methods

    private func _parse(_ file: FileWrapper,
                        compressed: Bool) throws -> MusicXML.Entity {
        let data = try file.contentsOfRegularFile()

        return try MusicXML.Parser().parse(data,
                                           compressed: compressed)
    }

    private func _read(_ file: FileWrapper,
                       compressed: Bool) throws -> [Work] {
        switch try _parse(file,
                          compressed: compressed) {
        case let .scorePartwise(score):
            return try [MusicXML.Converter().convert(score)]

        case let .scoreTimewise(score):
            return try [MusicXML.Converter().convert(score)]

        default:
            throw MusicXML.Error.parseFailure(nil)
        }
    }
}

// MARK: - Sendable

extension MusicXML.Importer: Sendable {
}
