// © 2025–2026 John Gary Pusey (see LICENSE.md)

public import Foundation
public import IvorModel

/// A value that encapsulates a file format supported for importing works.
public struct ImportFileFormat {

    // MARK: Public Type Properties

    /// The sorted array of preferred filename extensions across all supported import formats.
    public static let preferredFilenameExtensions = Set(importFileFormats.compactMap { $0.value.preferredFilenameExtension }).sorted()

    /// The sorted array of preferred MIME types across all supported import formats.
    public static let preferredMIMETypes = Set(importFileFormats.compactMap { $0.value.preferredMIMEType }).sorted()

    /// The sorted array of all supported filename extensions across all import formats.
    public static let supportedFilenameExtensions = Set(importFileFormats.flatMap { $0.value.filenameExtensions }).sorted()

    /// The sorted array of all supported MIME types across all import formats.
    public static let supportedMIMETypes = Set(importFileFormats.flatMap { $0.value.mimeTypes }).sorted()

    // MARK: Public Type Methods

    /// Returns the import file format for the given filename extension or MIME type.
    ///
    /// - Parameter tag:    The filename extension or MIME type to look up.
    ///
    /// - Returns:  The matching ``ImportFileFormat``, or `nil` if none is found.
    public static func importFileFormat(for tag: String) -> Self? {
        importFileFormats[tag]
    }

    // MARK: Public Instance Properties

    /// The human-readable display name for this import format.
    public var displayName: String {
        fileFormat.displayName
    }

    /// The sorted array of filename extensions for this import format.
    public var filenameExtensions: [String] {
        fileFormat.filenameExtensions.sorted()
    }

    /// The sorted array of MIME types for this import format.
    public var mimeTypes: [String] {
        fileFormat.mimeTypes.sorted()
    }

    /// The preferred filename extension for this import format, if any.
    public var preferredFilenameExtension: String? {
        fileFormat.preferredFilenameExtension
    }

    /// The preferred MIME type for this import format, if any.
    public var preferredMIMEType: String? {
        fileFormat.preferredMIMEType
    }

    // MARK: Public Instance Methods

    /// Returns a Boolean value indicating whether this format supports the given filename extension or MIME type.
    ///
    /// - Parameter tag:    The filename extension or MIME type to check.
    ///
    /// - Returns:  `true` if the format supports `tag`; otherwise, `false`.
    public func canRead(from tag: String) -> Bool {
        fileFormat.filenameExtensions.contains(tag) || fileFormat.mimeTypes.contains(tag)
    }

    /// Reads works from the given file wrapper in this import format.
    ///
    /// - Parameter file:   The file wrapper to read from.
    ///
    /// - Returns:  The array of works decoded from the file.
    ///
    /// - Throws:   Any error encountered while importing works from the file.
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
