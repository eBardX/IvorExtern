// © 2025–2026 John Gary Pusey (see LICENSE.md)

internal import IvorTiming
internal import IvorTuning

private import Foundation
private import XestiTools

internal struct FileFormat {

    // MARK: Internal Initializers

    internal init(displayName: String,
                  filenameExtensions: [String] = [],
                  mimeTypes: [String] = [],
                  pitchNotations: [PitchNotation] = [],
                  timeBases: [TimeBasis] = []) {
        self.displayName = displayName
        self.filenameExtensions = filenameExtensions
        self.mimeTypes = mimeTypes
        self.pitchNotations = pitchNotations
        self.timeBases = timeBases
        self.uniqueID = UUID().hexString
    }

    // MARK: Internal Instance Properties

    internal let displayName: String
    internal let filenameExtensions: [String]
    internal let mimeTypes: [String]
    internal let pitchNotations: [PitchNotation]
    internal let timeBases: [TimeBasis]
    internal let uniqueID: String
}

// MARK: -

extension FileFormat {

    // MARK: Internal Instance Properties

    internal var preferredFilenameExtension: String? {
        filenameExtensions.first
    }

    internal var preferredMIMEType: String? {
        mimeTypes.first
    }
}

// MARK: - CustomStringConvertible

extension FileFormat: CustomStringConvertible {
    internal var description: String {
        displayName
    }
}

// MARK: - Equatable

extension FileFormat: Equatable {
    internal static func == (lhs: Self,
                             rhs: Self) -> Bool {
        lhs.uniqueID == rhs.uniqueID
    }
}

// MARK: - Sendable

extension FileFormat: Sendable {
}
