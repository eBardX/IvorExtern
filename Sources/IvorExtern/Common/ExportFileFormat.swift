// © 2025–2026 John Gary Pusey (see LICENSE.md)

public import Foundation
public import IvorModel
public import IvorTiming
public import IvorTuning

/// A value that encapsulates a file format supported for exporting works.
public struct ExportFileFormat {

    // MARK: Public Type Methods

    /// The sorted array of preferred filename extensions across all supported export formats.
    public static let preferredFilenameExtensions = Set(exportFileFormats.compactMap { $0.value.preferredFilenameExtension }).sorted()

    /// The sorted array of preferred MIME types across all supported export formats.
    public static let preferredMIMETypes = Set(exportFileFormats.compactMap { $0.value.preferredMIMEType }).sorted()

    /// The sorted array of all supported filename extensions across all export formats.
    public static let supportedFilenameExtensions = Set(exportFileFormats.flatMap { $0.value.filenameExtensions }).sorted()

    /// The sorted array of all supported MIME types across all export formats.
    public static let supportedMIMETypes = Set(exportFileFormats.flatMap { $0.value.mimeTypes }).sorted()

    /// The sorted array of all supported pitch notations across all export formats.
    public static let supportedPitchNotations = Set(exportFileFormats.flatMap { $0.value.pitchNotations }).sorted()

    /// The sorted array of all supported time bases across all export formats.
    public static let supportedTimeBases = Set(exportFileFormats.flatMap { $0.value.timeBases }).sorted()

    // MARK: Public Type Methods

    /// Returns the export file format for the given filename extension or MIME type.
    ///
    /// - Parameter tag:    The filename extension or MIME type to look up.
    ///
    /// - Returns:  The matching ``ExportFileFormat``, or `nil` if none is found.
    public static func exportFileFormat(for tag: String) -> Self? {
        exportFileFormats[tag]
    }

    // MARK: Public Instance Properties

    /// The human-readable display name for this export format.
    public var displayName: String {
        fileFormat.displayName
    }

    /// The sorted array of filename extensions for this export format.
    public var filenameExtensions: [String] {
        fileFormat.filenameExtensions.sorted()
    }

    /// The sorted array of MIME types for this export format.
    public var mimeTypes: [String] {
        fileFormat.mimeTypes.sorted()
    }

    /// The sorted array of pitch notations for this export format.
    public var pitchNotations: [PitchNotation] {
        fileFormat.pitchNotations.sorted()
    }

    /// The preferred filename extension for this export format, if any.
    public var preferredFilenameExtension: String? {
        fileFormat.preferredFilenameExtension
    }

    /// The preferred MIME type for this export format, if any.
    public var preferredMIMEType: String? {
        fileFormat.preferredMIMEType
    }

    /// The sorted array of time bases for this export format.
    public var timeBases: [TimeBasis] {
        fileFormat.timeBases.sorted()
    }

    // MARK: Public Instance Methods

    /// Returns a Boolean value indicating whether this format supports the given filename extension or MIME type.
    ///
    /// - Parameter tag:    The filename extension or MIME type to check.
    ///
    /// - Returns:  `true` if the format supports `tag`; otherwise, `false`.
    public func canWrite(to tag: String) -> Bool {
        fileFormat.filenameExtensions.contains(tag) || fileFormat.mimeTypes.contains(tag)
    }

    /// Writes the provided works to a file wrapper in this export format.
    ///
    /// - Parameter works:  The array of works to export.
    ///
    /// - Returns:  A `FileWrapper` containing the exported data.
    ///
    /// - Throws:   Any error encountered while exporting the works.
    public func write(works: [Work]) throws -> FileWrapper {
        try exporter.write(works: works,
                           as: fileFormat)
    }

    // MARK: Private Type Properties

    private static let exportFileFormats: [String: Self] = {
        var dict: [String: Self] = [:]

        for exporter in exporters {
            for fileFormat in exporter.writableFileFormats {
                let exportFileFormat = Self(exporter: exporter,
                                            fileFormat: fileFormat)

                for tag in exportFileFormat.filenameExtensions {
                    dict[tag] = exportFileFormat
                }

                for tag in exportFileFormat.mimeTypes {
                    dict[tag] = exportFileFormat
                }
            }
        }

        return dict
    }()

    // MARK: Private Initializers

    private init(exporter: any ExporterProtocol,
                 fileFormat: FileFormat) {
        self.fileFormat = fileFormat
        self.exporter = exporter
    }

    // MARK: Private Instance Properties

    private let fileFormat: FileFormat
    private let exporter: any ExporterProtocol
}

// MARK: - Sendable

extension ExportFileFormat: Sendable {
}
