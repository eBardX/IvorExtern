// © 2025–2026 John Gary Pusey (see LICENSE.md)

public import Foundation
public import IvorModel
public import IvorTiming
public import IvorTuning

internal import XestiTools

/// A value that encapsulates a file format supported for importing works.
public struct ImportFileFormat {

    // MARK: Private Instance Properties

    private let fileFormat: FileFormat
    private let importer: any ImporterProtocol
}

// MARK: -

extension ImportFileFormat {

    // MARK: Public Type Properties

    /// The sorted array of preferred filename extensions across all supported import formats.
    public static let preferredFilenameExtensions = Set(importFileFormats.compactMap { $0.value.preferredFilenameExtension }).sorted()

    /// The sorted array of preferred MIME types across all supported import formats.
    public static let preferredMIMETypes = Set(importFileFormats.compactMap { $0.value.preferredMIMEType }).sorted()

    /// The sorted array of all supported filename extensions across all import formats.
    public static let supportedFilenameExtensions = Set(importFileFormats.flatMap { $0.value.filenameExtensions }).sorted()

    /// The sorted array of all supported MIME types across all import formats.
    public static let supportedMIMETypes = Set(importFileFormats.flatMap { $0.value.mimeTypes }).sorted()

    /// The sorted array of all supported pitch notations across all import formats.
    public static let supportedPitchNotations = Set(importFileFormats.flatMap { $0.value.pitchNotations }).sorted()

    /// The sorted array of all supported time bases across all import formats.
    public static let supportedTimeBases = Set(importFileFormats.flatMap { $0.value.timeBases }).sorted()

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

    /// The sorted array of pitch notations for this import format.
    public var pitchNotations: [PitchNotation] {
        fileFormat.pitchNotations.sorted()
    }

    /// The preferred filename extension for this import format, if any.
    public var preferredFilenameExtension: String? {
        fileFormat.preferredFilenameExtension
    }

    /// The preferred MIME type for this import format, if any.
    public var preferredMIMEType: String? {
        fileFormat.preferredMIMEType
    }

    /// The sorted array of time bases for this import format.
    public var timeBases: [TimeBasis] {
        fileFormat.timeBases.sorted()
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
    /// - Throws:   ``Error/readFailure(_:)`` if the works cannot be read from
    ///             the file.
    public func read(from file: FileWrapper) throws(Error) -> [Work] {
        do {
            return try importer.read(from: file,
                                     as: fileFormat)
        } catch let error as any EnhancedError {
            throw Error.readFailure(error)
        } catch {
            throw Error.readFailure(nil)
        }
    }

    // MARK: Private Type Properties

    private static let importFileFormats: [String: Self] = {
        var dict: [String: Self] = [:]

        for importer in importers {
            for fileFormat in importer.readableFileFormats {
                let importFileFormat = Self(fileFormat: fileFormat,
                                            importer: importer)

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
}

// MARK: - Sendable

extension ImportFileFormat: Sendable {
}
