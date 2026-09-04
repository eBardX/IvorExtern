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
                        compressed: Bool) throws(MusicXML.Error) -> MusicXML.Document {
        do {
            let (document, _) = try MusicXML.BaseParser().parse(data,
                                                                compressed: compressed)

            return document
        } catch let error as any EnhancedError {
            throw MusicXML.Error.parseFailure(error)
        } catch {
            throw MusicXML.Error.parseFailure(nil)
        }
    }
}

// MARK: - Sendable

extension MusicXML.Parser: Sendable {
}
