// © 2026 John Gary Pusey (see LICENSE.md)

internal import IvorABC

extension ABC {

    // MARK: Internal Nested Types

    // A resolved note: written pitch (already folded to sounding pitch and
    // respelled — see `ABC.Importer.Walker`), resolved duration, and the tie
    // to whatever note/chord follows, if any.
    internal struct Note {

        // MARK: Internal Instance Properties

        internal let duration: Duration
        internal let pitch: ABCPitch
        internal let tie: ABCTie?
    }
}

// MARK: - Equatable

extension ABC.Note: Equatable {
}

// MARK: - Sendable

extension ABC.Note: Sendable {
}
