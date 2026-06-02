// © 2026 John Gary Pusey (see LICENSE.md)

internal import Foundation

private import IvorJohnnySonic
private import XestiTools

extension JohnnySonic {
    internal struct Parser {
    }
}

// MARK: -

extension JohnnySonic.Parser {

    // MARK: Internal Instance Methods

    internal func parse(_ data: Data) throws -> JohnnySonic.Score {
        do {
            return try JohnnySonic.BaseParser().parse(data)
        } catch let error as any EnhancedError {
            throw JohnnySonic.Error.parseFailure(error)
        }
    }
}

// MARK: - Sendable

extension JohnnySonic.Parser: Sendable {
}
