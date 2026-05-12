internal import IvorGuido

internal struct Guido {

    // MARK: Internal Nested Types

    internal typealias BaseParser = GMNParser
    internal typealias Chord      = GMNChord
    internal typealias Duration   = GMNDuration
    internal typealias Note       = GMNNote
    internal typealias Pitch      = GMNPitch
    internal typealias Rest       = GMNRest
    internal typealias Score      = GMNScore
    internal typealias Symbol     = GMNSymbol
    internal typealias Tag        = GMNTag
    internal typealias Variable   = GMNVariable
    internal typealias Voice      = GMNVoice

    // MARK: Internal Instance Properties

    internal let exporter = Self.Exporter()
    internal let importer = Self.Importer()
}

// MARK: - External.Exportable

extension Guido: External.Exportable {
}

// MARK: - External.Importable

extension Guido: External.Importable {
}

// MARK: - Sendable

extension Guido: Sendable {
}
