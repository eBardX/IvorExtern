// © 2025–2026 John Gary Pusey (see LICENSE.md)

internal import IvorMIDI

internal struct MIDI {

    // MARK: Internal Nested Types

    internal typealias BaseParser = SMFParser
    internal typealias Channel    = MIDIChannel
    internal typealias Division   = SMFDivision
    internal typealias EventTime  = SMFEventTime
    internal typealias Note       = MIDIData1Value
    internal typealias Sequence   = SMFSequence
    internal typealias Track      = SMFTrack

    // MARK: Internal Instance Properties

    internal let exporter = Self.Exporter()
    internal let importer = Self.Importer()
}

// MARK: - External.Exportable

extension MIDI: External.Exportable {
}

// MARK: - External.Importable

extension MIDI: External.Importable {
}

// MARK: - Sendable

extension MIDI: Sendable {
}
