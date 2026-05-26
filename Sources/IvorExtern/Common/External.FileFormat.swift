// © 2025–2026 John Gary Pusey (see LICENSE.md)

private import Foundation
private import XestiTools

extension External {

    // MARK: Internal Nested Types

    internal struct FileFormat {

        // MARK: Internal Initializers

        internal init(displayName: String,
                      filenameExtensions: [String] = [],
                      mimeTypes: [String] = []) {
            self.displayName = displayName
            self.filenameExtensions = filenameExtensions
            self.mimeTypes = mimeTypes
            self.uniqueID = UUID().hexString
        }

        // MARK: Internal Instance Properties

        internal let displayName: String
        internal let filenameExtensions: [String]
        internal let mimeTypes: [String]
        internal let uniqueID: String
    }
}

// MARK: -

extension External.FileFormat {

    // MARK: Internal Instance Properties

    internal var preferredFilenameExtension: String? {
        filenameExtensions.first
    }

    internal var preferredMIMEType: String? {
        mimeTypes.first
    }
}

// MARK: - CustomStringConvertible

extension External.FileFormat: CustomStringConvertible {
    internal var description: String {
        displayName
    }
}

// MARK: - Equatable

extension External.FileFormat: Equatable {
    internal static func == (lhs: Self,
                             rhs: Self) -> Bool {
        lhs.uniqueID == rhs.uniqueID
    }
}

// MARK: - Sendable

extension External.FileFormat: Sendable {
}
