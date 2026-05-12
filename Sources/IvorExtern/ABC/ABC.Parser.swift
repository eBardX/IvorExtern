internal import Foundation

private import IvorABC
private import XestiTools

extension ABC {
    internal struct Parser {
    }
}

// MARK: -

extension ABC.Parser {

    // MARK: Internal Instance Methods

    internal func parse(_ data: Data) throws -> ABC.Tunebook {
        do {
            return try ABC.BaseParser().parse(data)
        } catch let error as any EnhancedError {
            throw ABC.Error.parseFailure(error)
        }
    }
}

// MARK: - Sendable

extension ABC.Parser: Sendable {
}
