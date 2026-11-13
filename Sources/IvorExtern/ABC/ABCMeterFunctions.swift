// © 2026 John Gary Pusey (see LICENSE.md)

internal import IvorABC
internal import IvorModel
internal import IvorTiming
internal import XestiTools

private import XestiNumbers

// MARK: Internal Functions

// A meter as an `M:` field's time signature: `none` if it's free; `C` or
// `C|` if a `meterSymbol` extra asks for it and matches the meter (4/4 or
// 2/2), since a transform can scale the meter without touching its extras;
// otherwise its groups over its denominator. ABC only writes a denominator
// that's a power of two up to 64, so any other meter is written as a
// stand-in of the same bar length (see `_abcStandInTimeSignature(_:)`), or
// as `none` if there isn't one.
internal func convertToABCTimeSignature(_ meter: Meter,
                                        _ extras: Extras?) -> ABCTimeSignature {
    guard let denominator = meter.denominator
    else { return .empty }

    switch (stringValue(extras, .meterSymbol), meter.plain) {
    case ("common", "4/4"):
        return .common

    case ("cut", "2/2"):
        return .cut

    default:
        break
    }

    if meter.numerators.count == 1 {
        if let standard = ABCTimeSignature.StandardMeter(numerator: meter.numerators[0],
                                                         denominator: denominator) {
            return .standard(standard)
        }
    } else if let additive = ABCTimeSignature.AdditiveMeter(numerators: meter.numerators,
                                                            denominator: denominator) {
        return .complex(additive)
    }

    return _abcStandInTimeSignature(meter) ?? .empty
}

// An `M:` field's meter: `C` is 4/4 and `C|` is 2/2 (each with a
// `meterSymbol`, see `convertToMeterExtras(_:)`), `none` is free, and a
// complex time signature such as `(2+2+3)/8` keeps its groups.
internal func convertToMeter(_ timeSignature: ABCTimeSignature) -> Meter? {
    switch timeSignature {
    case .common:
        Meter(numerators: [4],
              denominator: 4)

    case let .complex(additive):
        Meter(numerators: additive.numerators,
              denominator: additive.denominator)

    case .cut:
        Meter(numerators: [2],
              denominator: 2)

    case .empty:
        .free

    case let .standard(standard):
        Meter(numerators: [standard.numerator],
              denominator: standard.denominator)
    }
}

// An `M:` field's symbol, as a `meterSymbol` extra: `common` for `C` and
// `cut` for `C|`; `nil` for any other time signature.
internal func convertToMeterExtras(_ timeSignature: ABCTimeSignature) -> Extras? {
    let symbol = switch timeSignature {
    case .common:
        "common"

    case .cut:
        "cut"

    default:
        String?.none
    }

    return symbol.map {
        Extras(elements: [Extra(name: Extra.meterSymbol.name,
                                values: [.string($0)])])
    }
}

// MARK: Private Functions

// The time signature of the same bar length that stands in for a meter ABC
// can't write (6/12 as 2/4, 3/6 as 2/4), or `nil` if there's none (4/3,
// 7/12): its even pulse's note value as the denominator if that's a power of
// two ABC allows, otherwise the shortest of ♩ down to 1/64 that fits a whole
// number of times.
private func _abcStandInTimeSignature(_ meter: Meter) -> ABCTimeSignature? {
    guard let barLength = meter.barLength
    else { return nil }

    var denominators: [UInt] = []

    if let pulse = meter.evenPulse,
       pulse.numberValue.numerator == 1 {
        denominators.append(pulse.numberValue.denominator.uintValue)
    }

    denominators += [4, 8, 16, 32, 64]

    for denominator in denominators {
        let numerator = barLength.numberValue * Number(denominator)

        if numerator.denominator == 1,
           let standard = ABCTimeSignature.StandardMeter(numerator: numerator.numerator.uintValue,
                                                         denominator: denominator) {
            return .standard(standard)
        }
    }

    return nil
}
