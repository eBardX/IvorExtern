// © 2026 John Gary Pusey (see LICENSE.md)

internal import IvorGuido

extension Guido {

    // A fully resolved pitch: octave inheritance and accidental resolution
    // already applied. Unlike a written `GMNPitch`, whose accidental may be
    // `.omitted` and whose octave may be `nil`, this type always carries an
    // explicit accidental and octave. Unlike the upstream playback model's
    // equivalent type, this one has no access restriction on its
    // initializer, so `@testable` unit tests can construct one directly.
    internal struct Pitch {

        // MARK: Internal Instance Properties

        internal let accidental: Accidental
        internal let name: Name
        internal let octave: GMNPitch.Octave
    }
}

// MARK: - Equatable

extension Guido.Pitch: Equatable {
}

// MARK: - Sendable

extension Guido.Pitch: Sendable {
}
