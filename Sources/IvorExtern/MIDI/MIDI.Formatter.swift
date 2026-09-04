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

    internal func format(_ sequence: MIDI.Sequence) throws(MIDI.Error) -> Data {
        do {
            return try Self._format(sequence)
        } catch let error as any EnhancedError {
            throw MIDI.Error.formatFailure(error)
        } catch {
            throw MIDI.Error.formatFailure(nil)
        }
    }

    // MARK: Private Type Methods

    private static func _format(_ sequence: MIDI.Sequence) throws -> Data {
        let (normalized, _) = MIDI.Normalizer().normalize(sequence)
        let (validated, issues) = try MIDI.Validator().validate(normalized)

        guard issues.isEmpty
        else { throw MIDI.Error.validationFailure(issues) }

        return try MIDI.BaseFormatter().format(validated)
    }
}

// MARK: - Sendable

extension MIDI.Formatter: Sendable {
}
