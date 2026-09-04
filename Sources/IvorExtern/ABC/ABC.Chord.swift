// © 2026 John Gary Pusey (see LICENSE.md)

internal import IvorABC

extension ABC {

    // MARK: Internal Nested Types

    // A resolved chord: its member notes (each already carrying its own
    // combined duration — written length × unit note length × the chord's
    // own outer length modifier × any tuplet/broken-rhythm scaling, per
    // §4.17 of the ABC 2.1 standard) and the tie from the whole chord to
    // whatever follows, if any.
    internal struct Chord {

        // MARK: Internal Instance Properties

        internal let notes: [Note]
        internal let tie: ABCTie?
    }
}

// MARK: - Equatable

extension ABC.Chord: Equatable {
}

// MARK: - Sendable

extension ABC.Chord: Sendable {
}
