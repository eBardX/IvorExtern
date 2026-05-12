public import Foundation
public import IvorModel

public struct ImportFileFormat {

    // MARK: Public Type Properties

    public static let preferredFilenameExtensions = Set(importFileFormats.compactMap { $0.value.preferredFilenameExtension }).sorted()
    public static let preferredMIMETypes = Set(importFileFormats.compactMap { $0.value.preferredMIMEType }).sorted()
    public static let supportedFilenameExtensions = Set(importFileFormats.flatMap { $0.value.filenameExtensions }).sorted()
    public static let supportedMIMETypes = Set(importFileFormats.flatMap { $0.value.mimeTypes }).sorted()

    // MARK: Public Type Methods

    public static func importFileFormat(for tag: String) -> Self? {
        importFileFormats[tag]
    }

    // MARK: Public Instance Properties

    public var displayName: String {
        fileFormat.displayName
    }

    public var filenameExtensions: [String] {
        fileFormat.filenameExtensions.sorted()
    }

    public var mimeTypes: [String] {
        fileFormat.mimeTypes.sorted()
    }

    public var preferredFilenameExtension: String? {
        fileFormat.preferredFilenameExtension
    }

    public var preferredMIMEType: String? {
        fileFormat.preferredMIMEType
    }

    // MARK: Public Instance Methods

    public func canRead(from tag: String) -> Bool {
        fileFormat.filenameExtensions.contains(tag) || fileFormat.mimeTypes.contains(tag)
    }

    public func read(from file: FileWrapper) throws -> [Work] {
        try importer.read(from: file,
                          as: fileFormat)
    }

    // MARK: Private Type Properties

    private static let importFileFormats: [String: Self] = {
        var dict: [String: Self] = [:]

        for importer in External.importers {
            for fileFormat in importer.readableFileFormats {
                let importFileFormat = Self(importer: importer,
                                            fileFormat: fileFormat)

                for tag in importFileFormat.filenameExtensions {
                    dict[tag] = importFileFormat
                }

                for tag in importFileFormat.mimeTypes {
                    dict[tag] = importFileFormat
                }
            }
        }

        return dict
    }()

    // MARK: Private Initializers

    private init(importer: any External.Importer,
                 fileFormat: External.FileFormat) {
        self.fileFormat = fileFormat
        self.importer = importer
    }

    // MARK: Private Instance Properties

    private let fileFormat: External.FileFormat
    private let importer: any External.Importer
}

// MARK: - Sendable

extension ImportFileFormat: Sendable {
}
