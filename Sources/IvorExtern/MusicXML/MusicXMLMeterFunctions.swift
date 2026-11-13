// © 2026 John Gary Pusey (see LICENSE.md)

internal import IvorModel
internal import IvorMXL
internal import IvorTiming
internal import XestiTools

private import Foundation

// MARK: Internal Functions

// A `<time>`'s meter: `<senza-misura>` is free; otherwise every `<beats>`
// group (`3+2` is two) over one `<beat-type>`. Several signatures with
// different beat types (3/4 + 3/8) are brought over their least common
// beat type (6+3/8). Any beat type is accepted, so an irrational one (4/3)
// comes through as is. `nil` if a field isn't a positive whole number.
internal func convertToMeter(_ time: MXLTime) -> Meter? {
    switch time.content {
    case .senzaMisura:
        return .free

    case let .timeSignature(signatures, _):
        var groups: [(numerators: [UInt], beatType: UInt)] = []

        for signature in signatures {
            let fields = signature.beats.split(separator: "+",
                                               omittingEmptySubsequences: false)
            let numerators = fields.compactMap { UInt($0.trimmingCharacters(in: .whitespaces)) }

            guard numerators.count == fields.count,
                  let beatType = UInt(signature.beatType.trimmingCharacters(in: .whitespaces)),
                  beatType > 0
            else { return nil }

            groups.append((numerators, beatType))
        }

        let denominator = groups.reduce(1) { _lcm($0, $1.beatType) }

        return Meter(numerators: groups.flatMap { group in group.numerators.map { $0 * (denominator / group.beatType) } },
                     denominator: denominator)
    }
}

// A `<time>`'s `symbol`, as a `meterSymbol` extra: `common` (C) or `cut`
// (¢). Any other symbol is drawn from the numbers anyway, so it's dropped.
internal func convertToMeterExtras(_ time: MXLTime) -> Extras? {
    let symbol = switch time.symbol {
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

// A meter as a `<time>`: `<senza-misura>` if it's free, otherwise its groups
// joined by `+` over its denominator. A `meterSymbol` extra is drawn only if
// it matches the meter (C for 4/4, ¢ for 2/2), since a transform can scale
// the meter without touching its extras.
internal func convertToMusicXMLTime(_ meter: Meter,
                                    _ extras: Extras?) -> MXLTime {
    guard let denominator = meter.denominator
    else { return MXLTime(content: .senzaMisura("")) }

    let symbol: MXLTimeSymbol? = switch (stringValue(extras, .meterSymbol), meter.plain) {
    case ("common", "4/4"):
        .common

    case ("cut", "2/2"):
        .cut

    default:
        nil
    }

    let signature = MXLTimeSignature(beats: meter.numerators.map(String.init).joined(separator: "+"),
                                     beatType: String(denominator))

    return MXLTime(content: .timeSignature([signature], interchangeable: nil),
                   symbol: symbol)
}

// The barline at the start of a measure just walked, or `nil` if no meter
// is in force: the meter of the part-wide `<time>` (or else the first
// staff's), and its symbol only if the measure writes a `<time>` of its own
// (see `MusicXML.Importer.Context.barlines`).
internal func makeMusicXMLBarline(_ measure: MXLScorePartwise.Part.Measure,
                                  at beatTime: BeatTime,
                                  times: [UInt?: MXLTime]) -> (beatTime: BeatTime, meter: Meter, extras: Extras?)? {
    guard let time = times[nil] ?? times[1] ?? times.values.first,
          let meter = convertToMeter(time)
    else { return nil }

    let isTimeWritten = measure.items.contains {
        if case let .attributes(attributes) = $0 { !attributes.time.isEmpty } else { false }
    }

    return (beatTime,
            meter,
            isTimeWritten ? convertToMeterExtras(time) : nil)
}

// MARK: Private Functions

private func _gcd(_ lhs: UInt,
                  _ rhs: UInt) -> UInt {
    rhs == 0 ? lhs : _gcd(rhs, lhs % rhs)
}

private func _lcm(_ lhs: UInt,
                  _ rhs: UInt) -> UInt {
    lhs / _gcd(lhs, rhs) * rhs
}
