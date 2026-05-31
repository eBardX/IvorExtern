// © 2025–2026 John Gary Pusey (see LICENSE.md)

internal import IvorMIDI

internal struct MIDI {

    // MARK: Internal Nested Types

    internal typealias BaseFormatter = SMFFormatter
    internal typealias BaseParser    = SMFParser
    internal typealias Channel       = MIDIChannel
    internal typealias Division      = SMFDivision
    internal typealias Event         = SMFEvent
    internal typealias EventTime     = SMFEventTime
    internal typealias KeyVelocity   = MIDIData1Value
    internal typealias NoteNumber    = MIDIData1Value
    internal typealias PanValue      = MIDIData1Value
    internal typealias Sequence      = SMFSequence
    internal typealias Tempo         = SMFTempo
    internal typealias Text          = SMFText
    internal typealias TickRate      = SMFTickRate
    internal typealias TimeSignature = SMFTimeSignature
    internal typealias Track         = SMFTrack

    // MARK: Internal Instance Properties

    internal let exporter = Self.Exporter()
    internal let importer = Self.Importer()
}

// MARK: - Exportable

extension MIDI: Exportable {
}

// MARK: - Importable

extension MIDI: Importable {
}

// MARK: - Sendable

extension MIDI: Sendable {
}
