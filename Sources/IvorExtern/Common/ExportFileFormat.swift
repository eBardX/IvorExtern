public import Foundation
public import IvorModel

public struct ExportFileFormat {

    // MARK: Public Type Methods

    public static let preferredFilenameExtensions = Set(exportFileFormats.compactMap { $0.value.preferredFilenameExtension }).sorted()
    public static let preferredMIMETypes = Set(exportFileFormats.compactMap { $0.value.preferredMIMEType }).sorted()
    public static let supportedFilenameExtensions = Set(exportFileFormats.flatMap { $0.value.filenameExtensions }).sorted()
    public static let supportedMIMETypes = Set(exportFileFormats.flatMap { $0.value.mimeTypes }).sorted()

    // MARK: Public Type Methods

    public static func exportFileFormat(for tag: String) -> Self? {
        exportFileFormats[tag]
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

    public func canWrite(to tag: String) -> Bool {
        fileFormat.filenameExtensions.contains(tag) || fileFormat.mimeTypes.contains(tag)
    }

    public func write(works: [Work]) throws -> FileWrapper {
        try exporter.write(works: works,
                           as: fileFormat)
    }

    // MARK: Private Type Properties

    private static let exportFileFormats: [String: Self] = {
        var dict: [String: Self] = [:]

        for exporter in External.exporters {
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

    private init(exporter: any External.Exporter,
                 fileFormat: External.FileFormat) {
        self.fileFormat = fileFormat
        self.exporter = exporter
    }

    // MARK: Private Instance Properties

    private let fileFormat: External.FileFormat
    private let exporter: any External.Exporter
}

// MARK: - Sendable

extension ExportFileFormat: Sendable {
}
