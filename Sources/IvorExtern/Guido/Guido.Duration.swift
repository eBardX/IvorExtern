// © 2026 John Gary Pusey (see LICENSE.md)

internal import XestiNumbers

extension Guido {

    // A fully resolved duration, expressed as a fraction of a whole note —
    // dots and inheritance already applied. Unlike the upstream playback
    // model's equivalent type, a numerator/denominator pair reduced by hand,
    // this one is a thin wrapper around `Number`'s own rational arithmetic,
    // so `_applyDots` in `Guido.Importer.Walker` needs no separate
    // reduction step of its own. It is deliberately not `Number` itself —
    // `Number` conforms to `ExpressibleByIntegerLiteral`, and another
    // format's `convertToBeatDuration` overload already claims that
    // literal.
    internal struct Duration {

        // MARK: Internal Instance Properties

        internal let numberValue: Number
    }
}

// MARK: - Equatable

extension Guido.Duration: Equatable {
}

// MARK: - Sendable

extension Guido.Duration: Sendable {
}
