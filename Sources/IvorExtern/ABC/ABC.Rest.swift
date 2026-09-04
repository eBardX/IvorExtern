// © 2026 John Gary Pusey (see LICENSE.md)

extension ABC {

    // MARK: Internal Nested Types

    internal struct Rest {

        // MARK: Internal Instance Properties

        internal let duration: Duration
    }
}

// MARK: - Equatable

extension ABC.Rest: Equatable {
}

// MARK: - Sendable

extension ABC.Rest: Sendable {
}
