// © 2025–2026 John Gary Pusey (see LICENSE.md)

internal import Foundation

extension MIDI {
    internal struct Formatter {
    }
}

// MARK: -

extension MIDI.Formatter {

    // MARK: Internal Instance Methods

    internal func format(_ score: MIDI.Sequence) throws -> Data {
        throw MIDI.Error.formatFailure(nil)
    }
}

// MARK: - Sendable

extension MIDI.Formatter: Sendable {
}
