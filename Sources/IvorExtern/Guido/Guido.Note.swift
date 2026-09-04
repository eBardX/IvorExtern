// © 2026 John Gary Pusey (see LICENSE.md)

extension Guido {

    // A fully resolved note: pitch and duration already inherited and
    // dotted. Unlike the upstream playback model's equivalent type, this
    // one has no access restriction on its initializer, so `@testable`
    // unit tests can construct one directly.
    internal struct Note {

        // MARK: Internal Instance Properties

        internal let duration: Duration
        internal let pitch: Pitch
    }
}

// MARK: - Equatable

extension Guido.Note: Equatable {
}

// MARK: - Sendable

extension Guido.Note: Sendable {
}
