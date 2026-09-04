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

    internal func parse(_ data: Data) throws(JohnnySonic.Error) -> JohnnySonic.Score {
        do {
            let (score, _) = try JohnnySonic.BaseParser().parse(data)

            return score
        } catch let error as any EnhancedError {
            throw JohnnySonic.Error.parseFailure(error)
        } catch {
            throw JohnnySonic.Error.parseFailure(nil)
        }
    }
}

// MARK: - Sendable

extension JohnnySonic.Parser: Sendable {
}
