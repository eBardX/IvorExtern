// © 2025–2026 John Gary Pusey (see LICENSE.md)

internal import Foundation

private import IvorMusicXML
private import XestiTools

extension MusicXML {
    internal struct Parser {
    }
}

// MARK: -

extension MusicXML.Parser {

    // MARK: Internal Instance Methods

    internal func parse(_ data: Data,
                        compressed: Bool) throws -> MusicXML.Entity {
        do {
            return try MusicXML.BaseParser().parse(data,
                                                   compressed: compressed)
        } catch let error as any EnhancedError {
            throw MusicXML.Error.parseFailure(error)
        }
    }
}

// MARK: - Sendable

extension MusicXML.Parser: Sendable {
}
