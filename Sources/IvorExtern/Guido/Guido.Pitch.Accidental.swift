// © 2026 John Gary Pusey (see LICENSE.md)

extension Guido.Pitch {

    // The resolved accidental of a pitch — an omitted accidental already
    // resolved to `.natural`, and an implied sharp (carried by a German
    // chromatic pitch name, e.g. `cis`) already resolved to `.sharp`.
    internal enum Accidental {
        case doubleFlat
        case doubleSharp
        case flat
        case natural
        case sharp
    }
}

// MARK: - Equatable

extension Guido.Pitch.Accidental: Equatable {
}

// MARK: - Sendable

extension Guido.Pitch.Accidental: Sendable {
}
