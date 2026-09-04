// © 2025–2026 John Gary Pusey (see LICENSE.md)

internal import IvorMusicXML

internal struct MusicXML {

    // MARK: Internal Type Aliases

    internal typealias BaseFormatter = MXLFormatter
    internal typealias BaseParser    = MXLParser
    internal typealias Document      = MXLDocument
    internal typealias Normalizer    = MXLNormalizer
    internal typealias Octave        = MXLOctave
    internal typealias Pitch         = MXLPitch
    internal typealias Score         = MXLScorePartwise
    internal typealias ScorePart     = MXLScorePart
    internal typealias Semitones     = MXLSemitones
    internal typealias Step          = MXLStep
    internal typealias Validator     = MXLValidator

    // MARK: Internal Instance Properties

    internal let exporter = Self.Exporter()
    internal let importer = Self.Importer()
}

// MARK: - Exportable

extension MusicXML: Exportable {
}

// MARK: - Importable

extension MusicXML: Importable {
}

// MARK: - Sendable

extension MusicXML: Sendable {
}
