// © 2026 John Gary Pusey (see LICENSE.md)

internal import XestiNumbers

// A whole-note-fraction duration or onset, wrapping `Number` rather than
// aliasing it directly — matching `Guido.Duration`/`ABC.Duration` — so this
// type doesn't collide with those formats' own `convertToBeatDuration`
// overloads. Unlike an ABC or Guido duration, a `MusicXML.Duration` also
// represents an absolute onset measured from the start of the score, so a
// numerator of zero (the score start) is valid.
extension MusicXML {
    internal struct Duration {

        // MARK: Internal Initializers

        internal init(numberValue: Number) {
            self.numberValue = numberValue
        }

        // MARK: Internal Instance Properties

        internal let numberValue: Number
    }
}

// MARK: -

extension MusicXML.Duration {

    // MARK: Internal Type Properties

    internal static let zero = Self(numberValue: 0)

    // MARK: Internal Type Methods

    internal static func + (lhs: Self,
                            rhs: Self) -> Self {
        Self(numberValue: lhs.numberValue + rhs.numberValue)
    }

    internal static func += (lhs: inout Self,
                             rhs: Self) {
        lhs = lhs + rhs
    }

    // Subtracts `rhs` from `lhs`, or returns `nil` if the result would be
    // negative — the signal for an unbalanced `<backup>`.
    internal static func subtracting(_ lhs: Self,
                                     _ rhs: Self) -> Self? {
        guard rhs.numberValue <= lhs.numberValue
        else { return nil }

        return Self(numberValue: lhs.numberValue - rhs.numberValue)
    }
}

// MARK: - Comparable

extension MusicXML.Duration: Comparable {
    internal static func < (lhs: Self,
                            rhs: Self) -> Bool {
        lhs.numberValue < rhs.numberValue
    }
}

// MARK: - Equatable

extension MusicXML.Duration: Equatable {
}

// MARK: - Hashable

extension MusicXML.Duration: Hashable {
}

// MARK: - Sendable

extension MusicXML.Duration: Sendable {
}
