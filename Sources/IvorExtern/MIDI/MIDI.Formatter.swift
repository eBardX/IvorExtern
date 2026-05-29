// © 2025–2026 John Gary Pusey (see LICENSE.md)

internal import Foundation
internal import IvorMIDI

private import XestiTools

extension MIDI {
    internal struct Formatter {
    }
}

// MARK: -

extension MIDI.Formatter {

    // MARK: Internal Instance Methods

    internal func format(_ sequence: MIDI.Sequence) throws -> Data {
        do {
            return try MIDI.BaseFormatter().format(sequence)
        } catch let error as any EnhancedError {
            throw MIDI.Error.formatFailure(error)
        }
    }
}

// MARK: - Sendable

extension MIDI.Formatter: Sendable {
}
