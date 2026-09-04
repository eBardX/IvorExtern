// © 2026 John Gary Pusey (see LICENSE.md)

extension Guido {

    // A fully resolved rest. Unlike the upstream playback model's
    // equivalent type, this one has no access restriction on its
    // initializer, so `@testable` unit tests can construct one directly.
    internal struct Rest {

        // MARK: Internal Instance Properties

        internal let duration: Duration
    }
}

// MARK: - Equatable

extension Guido.Rest: Equatable {
}

// MARK: - Sendable

extension Guido.Rest: Sendable {
}
