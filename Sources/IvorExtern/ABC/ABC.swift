// © 2025–2026 John Gary Pusey (see LICENSE.md)

internal import IvorABC

internal struct ABC {

    // MARK: Internal Type Aliases

    internal typealias BaseFormatter = ABCFormatter
    internal typealias BaseParser    = ABCParser
    internal typealias Normalizer    = ABCNormalizer
    internal typealias Pitch         = ABCPitch
    internal typealias Tunebook      = ABCTunebook
    internal typealias Validator     = ABCValidator
    internal typealias Voice         = ABCVoice

    // MARK: Internal Instance Properties

    internal let exporter = Self.Exporter()
    internal let importer = Self.Importer()
}

// MARK: - Exportable

extension ABC: Exportable {
}

// MARK: - Importable

extension ABC: Importable {
}

// MARK: - Sendable

extension ABC: Sendable {
}
