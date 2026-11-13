// © 2026 John Gary Pusey (see LICENSE.md)

internal import IvorTiming
internal import XestiNumbers

// MARK: Internal Functions

// The number of dots (0 or 1) that makes `unit` a plain or dotted note
// value — a power of two times a whole note, or 3/2 of one — along with
// that undotted value, or `nil` if it's neither. Exporters whose tempo
// marks name a single note value (MusicXML's `<metronome>`) write a unit
// like this as is, and restate any other tempo in quarter notes.
internal func plainOrDottedNoteValue(_ unit: BeatDuration) -> (base: Number, dots: UInt)? {
    let value = unit.numberValue

    guard value.isRational,
          value.numerator > 0
    else { return nil }

    if _isPowerOfTwo(value) {
        return (value, 0)
    }

    let base = value * Number(numerator: 2,
                              denominator: 3)

    if _isPowerOfTwo(base) {
        return (base, 1)
    }

    return nil
}

// A tempo's rate as a whole number, rounded to the nearest one with halves
// rounding up (as `Tempo.FormatStyle` shows it), and never less than 1, for
// formats that can only write a whole-number rate.
internal func roundedTempoRate(_ tempo: Tempo) -> UInt {
    let rounded = floor(tempo.rate + Number(numerator: 1,
                                            denominator: 2)).exact

    guard rounded > 1
    else { return 1 }

    return rounded.uintValue
}

// MARK: Private Functions

private func _isPowerOfTwo(_ value: Number) -> Bool {
    let numerator = value.numerator.uintValue
    let denominator = value.denominator.uintValue

    return (numerator == 1 && denominator.nonzeroBitCount == 1)
        || (denominator == 1 && numerator.nonzeroBitCount == 1)
}
