// © 2025–2026 John Gary Pusey (see LICENSE.md)

internal import Foundation

private import IvorGuido
private import XestiTools

extension Guido {
    internal struct Parser {
    }
}

// MARK: -

extension Guido.Parser {

    // MARK: Internal Instance Methods

    internal func parse(_ data: Data) throws -> Guido.Score {
        do {
            return try Guido.BaseParser().parse(data)
        } catch let error as any EnhancedError {
            throw Guido.Error.parseFailure(error)
        }
    }
}

// MARK: - Sendable

extension Guido.Parser: Sendable {
}
