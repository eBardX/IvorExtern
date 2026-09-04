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

    internal func parse(_ data: Data) throws(Guido.Error) -> Guido.Score {
        do {
            let (score, _) = try Guido.BaseParser().parse(data)
            let (normalized, _) = GMNNormalizer().normalize(score)

            return normalized
        } catch let error as any EnhancedError {
            throw Guido.Error.parseFailure(error)
        } catch {
            throw Guido.Error.parseFailure(nil)
        }
    }
}

// MARK: - Sendable

extension Guido.Parser: Sendable {
}
