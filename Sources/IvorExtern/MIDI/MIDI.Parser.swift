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

    internal func parse(_ data: Data) throws -> MIDI.Sequence {
        do {
            return try MIDI.BaseParser().parse(data)
        } catch let error as any EnhancedError {
            throw MIDI.Error.parseFailure(error)
        }
    }
}

// MARK: - Sendable

extension MIDI.Parser: Sendable {
}
