// © 2026 John Gary Pusey (see LICENSE.md)

internal import Foundation
internal import IvorMusicXML

private import XestiTools

extension MusicXML {
    internal struct Formatter {
    }
}

// MARK: -

extension MusicXML.Formatter {

    // MARK: Internal Instance Methods

    internal func format(_ document: MusicXML.Document,
                         compressed: Bool) throws(MusicXML.Error) -> Data {
        do {
            let (normalized, _) = MusicXML.Normalizer().normalize(document)
            let (validated, issues) = try MusicXML.Validator().validate(normalized)

            guard issues.isEmpty
            else { throw MusicXML.Error.validationFailure(issues) }

            return try MusicXML.BaseFormatter().format(validated,
                                                       compressed: compressed)
        } catch let error as any EnhancedError {
            throw MusicXML.Error.formatFailure(error)
        } catch {
            throw MusicXML.Error.formatFailure(nil)
        }
    }
}

// MARK: - Sendable

extension MusicXML.Formatter: Sendable {
}
