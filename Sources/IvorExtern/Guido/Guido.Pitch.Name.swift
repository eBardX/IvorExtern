// © 2026 John Gary Pusey (see LICENSE.md)

extension Guido.Pitch {

    // The resolved name of a pitch — every German chromatic spelling,
    // German `h`, and solfège syllable already collapsed onto its
    // underlying letter name. The German sharp inflection carried by a
    // chromatic spelling surfaces separately, in `Accidental`.
    internal enum Name {
        case a
        case b
        case c
        case d
        case e
        case empty
        case f
        case g
    }
}

// MARK: - Equatable

extension Guido.Pitch.Name: Equatable {
}

// MARK: - Sendable

extension Guido.Pitch.Name: Sendable {
}
