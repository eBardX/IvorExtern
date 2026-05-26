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

    internal func format(_ score: JohnnySonic.Score) throws -> Data {
        do {
            return try JohnnySonic.BaseFormatter().format(score)
        } catch let error as any EnhancedError {
            throw JohnnySonic.Error.formatFailure(error)
        }
    }
}

// MARK: - Sendable

extension JohnnySonic.Formatter: Sendable {
}
