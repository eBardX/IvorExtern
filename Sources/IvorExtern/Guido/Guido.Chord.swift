// © 2026 John Gary Pusey (see LICENSE.md)

extension Guido {

    // A fully resolved chord: the resolved note in each music-bearing
    // segment, gathered in segment order. Unlike `GMNChord`, whose segments
    // may each carry their own independently written or inherited
    // duration, this type carries no chord-level duration at all — advance
    // uses the `max` of its members' durations instead, since GMN chords
    // carry no duration of their own. Unlike the upstream playback model's
    // equivalent type, this one has no access restriction on its
    // initializer, so `@testable` unit tests can construct one directly.
    internal struct Chord {

        // MARK: Internal Instance Properties

        internal let notes: [Note]
    }
}

// MARK: - Equatable

extension Guido.Chord: Equatable {
}

// MARK: - Sendable

extension Guido.Chord: Sendable {
}
