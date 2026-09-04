// © 2026 John Gary Pusey (see LICENSE.md)

internal import Foundation
internal import IvorABC

private import XestiTools

extension ABC {
    internal struct Formatter {
    }
}

// MARK: -

extension ABC.Formatter {

    // MARK: Internal Instance Methods

    internal func format(_ tunebook: ABCTunebook) throws(ABC.Error) -> Data {
        do {
            let (normalized, _) = ABC.Normalizer().normalize(tunebook)
            let (validated, issues) = try ABC.Validator().validate(normalized)

            guard issues.isEmpty
            else { throw ABC.Error.validationFailure(issues) }

            return try ABC.BaseFormatter().format(validated)
        } catch let error as any EnhancedError {
            throw ABC.Error.formatFailure(error)
        } catch {
            throw ABC.Error.formatFailure(nil)
        }
    }
}

// MARK: - Sendable

extension ABC.Formatter: Sendable {
}
