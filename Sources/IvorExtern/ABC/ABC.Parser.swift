// © 2025–2026 John Gary Pusey (see LICENSE.md)

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

    internal func parse(_ data: Data) throws(ABC.Error) -> ABC.Tunebook {
        do {
            let (tunebook, _) = try ABC.BaseParser().parse(data)

            return tunebook
        } catch let error as any EnhancedError {
            throw ABC.Error.parseFailure(error)
        } catch {
            throw ABC.Error.parseFailure(nil)
        }
    }
}

// MARK: - Sendable

extension ABC.Parser: Sendable {
}
