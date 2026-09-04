// © 2026 John Gary Pusey (see LICENSE.md)

internal import IvorABC
internal import XestiNumbers

// A resolved duration, expressed as a fraction of a whole note. Deliberately
// a distinct wrapper around `Number` rather than a bare alias — `Number`
// itself conforms to `ExpressibleByIntegerLiteral`, and Guido's `Duration`
// already demonstrated that an integer-literal `convertToBeatDuration`
// call site elsewhere in the module becomes ambiguous the moment two
// formats' overloads both resolve through `ExpressibleByIntegerLiteral`
// types.
extension ABC {

    // MARK: Internal Nested Types

    internal struct Duration {

        // MARK: Internal Initializers

        // `length`, already validated by the parser, is guaranteed to have a
        // nonzero denominator.
        internal init(length: ABCLength) {
            self.init(numberValue: Number(numerator: length.numerator,
                                          denominator: length.denominator))
        }

        internal init(numberValue: Number) {
            self.numberValue = numberValue
        }

        // Resolves a written length (a multiplier of the unit note length)
        // against the active unit note length — the same
        // `written × unitNoteLength` formula upstream's own duration
        // resolution uses.
        internal init(written: ABCLength,
                      unitNoteLength: (numerator: UInt, denominator: UInt)) {
            self.init(numberValue: Number(numerator: written.numerator * unitNoteLength.numerator,
                                          denominator: written.denominator * unitNoteLength.denominator))
        }

        // MARK: Internal Instance Properties

        internal let numberValue: Number
    }
}

// MARK: -

extension ABC.Duration {

    // MARK: Internal Type Methods

    // Returns the sum of two durations. Used for tie coalescing.
    internal static func + (lhs: Self,
                            rhs: Self) -> Self {
        Self(numberValue: lhs.numberValue + rhs.numberValue)
    }

    // Returns this duration scaled by the fraction `numerator / denominator`.
    // Used to scale by a tuplet ratio, a broken-rhythm factor, or a chord's
    // own outer length modifier.
    internal static func * (lhs: Self,
                            rhs: (numerator: UInt, denominator: UInt)) -> Self {
        Self(numberValue: lhs.numberValue * Number(numerator: rhs.numerator,
                                                   denominator: rhs.denominator))
    }
}

// MARK: - Equatable

extension ABC.Duration: Equatable {
}

// MARK: - Sendable

extension ABC.Duration: Sendable {
}
