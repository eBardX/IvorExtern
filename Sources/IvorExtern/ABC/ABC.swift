// © 2025–2026 John Gary Pusey (see LICENSE.md)

internal import IvorABC

internal struct ABC {

    // MARK: Internal Nested Types

    internal typealias BaseParser = ABCParser
    internal typealias Duration   = ABCDuration
    internal typealias Entry      = ABCEntry
    internal typealias Field      = ABCField
    internal typealias Header     = ABCHeader
    internal typealias Note       = ABCNote
    internal typealias Pitch      = ABCPitch
    internal typealias Rest       = ABCRest
    internal typealias Symbol     = ABCSymbol
    internal typealias Tune       = ABCTune
    internal typealias Tunebook   = ABCTunebook
    internal typealias Voice      = ABCVoice

    // MARK: Internal Instance Properties

    internal let exporter = Self.Exporter()
    internal let importer = Self.Importer()
}

// MARK: - External.Exportable

extension ABC: External.Exportable {
}

// MARK: - External.Importable

extension ABC: External.Importable {
}

// MARK: - Sendable

extension ABC: Sendable {
}
