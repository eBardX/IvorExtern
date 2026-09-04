// © 2025–2026 John Gary Pusey (see LICENSE.md)

internal import Foundation
internal import IvorJohnnySonic

private import XestiTools

extension JohnnySonic {
    internal struct Formatter {
    }
}

// MARK: -

extension JohnnySonic.Formatter {

    // MARK: Internal Instance Methods

    internal func format(_ score: JohnnySonic.Score) throws(JohnnySonic.Error) -> Data {
        do {
            let (normalized, _) = DKMNormalizer().normalize(score)
            let (validated, issues) = try DKMValidator().validate(normalized)

            guard issues.isEmpty
            else { throw JohnnySonic.Error.validationFailure(issues) }

            return try JohnnySonic.BaseFormatter().format(validated)
        } catch let error as any EnhancedError {
            throw JohnnySonic.Error.formatFailure(error)
        } catch {
            throw JohnnySonic.Error.formatFailure(nil)
        }
    }
}

// MARK: - Sendable

extension JohnnySonic.Formatter: Sendable {
}
