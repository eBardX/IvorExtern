// © 2025–2026 John Gary Pusey (see LICENSE.md)

internal import Foundation

private import IvorMIDI
private import XestiTools

extension MIDI {
    internal struct Parser {
    }
}

// MARK: -

extension MIDI.Parser {

    // MARK: Internal Instance Methods

    internal func parse(_ data: Data) throws(MIDI.Error) -> MIDI.Sequence {
        do {
            let (sequence, _) = try MIDI.BaseParser().parse(data)

            return sequence
        } catch let error as any EnhancedError {
            throw MIDI.Error.parseFailure(error)
        } catch {
            throw MIDI.Error.parseFailure(nil)
        }
    }
}

// MARK: - Sendable

extension MIDI.Parser: Sendable {
}
