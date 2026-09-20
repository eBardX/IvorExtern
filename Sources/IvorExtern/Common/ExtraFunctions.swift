// © 2026 John Gary Pusey (see LICENSE.md)

internal import XestiTools

// Looks up `extra`'s `.string` payload in `extras`, if present under that
// name with exactly that shape. `nil` for a missing name, a bare flag with
// no payload, or a payload of a different associated-value case.
internal func stringValue(_ extras: Extras?, _ extra: Extra) -> String? {
    guard case let .string(value)? = extras?.elements.first(where: { $0.name == extra.name })?.values.first
    else { return nil }

    return value
}

// Looks up `extra`'s `.int` payload in `extras`, if present under that name
// with exactly that shape. `nil` for a missing name, a bare flag with no
// payload, or a payload of a different associated-value case.
internal func intValue(_ extras: Extras?, _ extra: Extra) -> Int? {
    guard case let .int(value)? = extras?.elements.first(where: { $0.name == extra.name })?.values.first
    else { return nil }

    return value
}

// Looks up `extra`'s `.double` payload in `extras`, if present under that
// name with exactly that shape. `nil` for a missing name, a bare flag with
// no payload, or a payload of a different associated-value case.
internal func doubleValue(_ extras: Extras?, _ extra: Extra) -> Double? {
    guard case let .double(value)? = extras?.elements.first(where: { $0.name == extra.name })?.values.first
    else { return nil }

    return value
}

// Whether a bare-flag `extra` (no payload) is present in `extras` under that
// name. `false` for a missing name; also `true` for a value-bearing extra of
// that name (presence, not payload shape, is what a flag checks).
internal func hasFlag(_ extras: Extras?, _ extra: Extra) -> Bool {
    extras?.elements.contains { $0.name == extra.name } ?? false
}
