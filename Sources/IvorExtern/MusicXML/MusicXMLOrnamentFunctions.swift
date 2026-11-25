// © 2026 John Gary Pusey (see LICENSE.md)

internal import IvorModel
internal import IvorMXL
internal import IvorTiming
internal import IvorTuning

private import XestiNumbers

// Conversions between MusicXML's ornament vocabulary and the model's: note
// types and their flags, fermata shapes, and accidental marks.

// MARK: Internal Functions

// The accidental an `<accidental-mark>` gives a written partner, if it's one
// a standard pitch can have.
internal func convertToAccidental(_ value: MXLAccidentalValue) -> Pitch.Accidental? {
    switch value {
    case .doubleSharp,
         .sharpSharp:
        .doubleSharp

    case .flat:
        .flat

    case .flatFlat:
        .doubleFlat

    case .natural:
        .natural

    case .sharp:
        .sharp

    default:
        nil
    }
}

// The written length of a note of `kind` with `dots` dots.
internal func convertToBeatDuration(kind: MXLNoteKindValue,
                                    dots: Int) -> BeatDuration? {
    let base = _wholeNotes(kind)
    var total = base
    var addend = base

    for _ in 0..<max(0, dots) {
        addend /= 2
        total += addend
    }

    return BeatDuration(numberValue: total)
}

// The fermata shape a `<fermata>` draws: `angled` is short, `square` long,
// `double-angled` very short and `double-square` very long; every other
// shape is normal. Whether it's inverted is layout (resolution 16 of the
// grace-notes plan).
internal func convertToFermataShape(_ shape: MXLFermata.Shape) -> FermataShape {
    switch shape {
    case .angled:
        .short

    case .curlew,
         .doubleDot,
         .empty,
         .halfCurve,
         .normal:
        .normal

    case .doubleAngled:
        .veryShort

    case .doubleSquare:
        .veryLong

    case .square:
        .long
    }
}

// The flags or beams of a note of `kind`.
internal func convertToFlagCount(kind: MXLNoteKindValue) -> UInt {
    switch kind {
    case .breve,
         .half,
         .long,
         .maxima,
         .quarter,
         .whole:
        0

    case .eighth:
        1

    case .n1024th:
        8

    case .n128th:
        5

    case .n16th:
        2

    case .n256th:
        6

    case .n32nd:
        3

    case .n512th:
        7

    case .n64th:
        4
    }
}

// The reverse of `convertToAccidental(_:)`.
internal func convertToMusicXMLAccidentalValue(_ accidental: Pitch.Accidental) -> MXLAccidentalValue {
    switch accidental {
    case .doubleFlat:
        .flatFlat

    case .doubleSharp:
        .doubleSharp

    case .flat:
        .flat

    case .natural:
        .natural

    case .sharp:
        .sharp
    }
}

// The reverse of `convertToFermataShape(_:)`.
internal func convertToMusicXMLFermataShape(_ shape: FermataShape) -> MXLFermata.Shape {
    switch shape {
    case .long:
        .square

    case .normal:
        .normal

    case .short:
        .angled

    case .veryLong:
        .doubleSquare

    case .veryShort:
        .doubleAngled
    }
}

// The note type and dots (up to two) that write `duration`, if any do.
internal func convertToMusicXMLNoteKind(_ duration: BeatDuration) -> (kind: MXLNoteKindValue, dots: Int)? {
    for kind in noteKinds {
        for dots in 0...2 where convertToBeatDuration(kind: kind, dots: dots) == duration {
            return (kind, dots)
        }
    }

    return nil
}

// MARK: Private Constants

private let noteKinds: [MXLNoteKindValue] = [.maxima,
                                             .long,
                                             .breve,
                                             .whole,
                                             .half,
                                             .quarter,
                                             .eighth,
                                             .n16th,
                                             .n32nd,
                                             .n64th,
                                             .n128th,
                                             .n256th,
                                             .n512th,
                                             .n1024th]

// MARK: Private Functions

private func _wholeNotes(_ kind: MXLNoteKindValue) -> Number {
    switch kind {
    case .breve:
        2

    case .eighth:
        Number(numerator: 1, denominator: 8)

    case .half:
        Number(numerator: 1, denominator: 2)

    case .long:
        4

    case .maxima:
        8

    case .n1024th:
        Number(numerator: 1, denominator: 1_024)

    case .n128th:
        Number(numerator: 1, denominator: 128)

    case .n16th:
        Number(numerator: 1, denominator: 16)

    case .n256th:
        Number(numerator: 1, denominator: 256)

    case .n32nd:
        Number(numerator: 1, denominator: 32)

    case .n512th:
        Number(numerator: 1, denominator: 512)

    case .n64th:
        Number(numerator: 1, denominator: 64)

    case .quarter:
        Number(numerator: 1, denominator: 4)

    case .whole:
        1
    }
}
