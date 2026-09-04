// © 2026 John Gary Pusey (see LICENSE.md)

internal import Foundation
internal import IvorGuido

private import XestiTools

extension Guido {
    internal struct Formatter {
    }
}

// MARK: -

extension Guido.Formatter {

    // MARK: Internal Instance Methods

    internal func format(_ score: Guido.Score) throws(Guido.Error) -> Data {
        do {
            let (normalized, _) = Guido.Normalizer().normalize(score)
            let (validated, issues) = try Guido.Validator().validate(normalized)

            guard issues.isEmpty
            else { throw Guido.Error.validationFailure(issues) }

            return try Guido.BaseFormatter().format(validated)
        } catch let error as any EnhancedError {
            throw Guido.Error.formatFailure(error)
        } catch {
            throw Guido.Error.formatFailure(nil)
        }
    }
}

// MARK: - Sendable

extension Guido.Formatter: Sendable {
}
