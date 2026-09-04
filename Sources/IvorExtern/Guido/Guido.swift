// © 2025–2026 John Gary Pusey (see LICENSE.md)

internal import IvorGuido

internal struct Guido {

    // MARK: Internal Type Aliases

    internal typealias BaseFormatter = GMNFormatter
    internal typealias BaseParser    = GMNParser
    internal typealias Event         = GMNSymbol
    internal typealias Normalizer    = GMNNormalizer
    internal typealias Score         = GMNScore
    internal typealias Symbol        = GMNSymbol
    internal typealias Tag           = GMNTag
    internal typealias Validator     = GMNValidator
    internal typealias Voice         = GMNVoice

    // MARK: Internal Instance Properties

    internal let exporter = Self.Exporter()
    internal let importer = Self.Importer()
}

// MARK: - Exportable

extension Guido: Exportable {
}

// MARK: - Importable

extension Guido: Importable {
}

// MARK: - Sendable

extension Guido: Sendable {
}
