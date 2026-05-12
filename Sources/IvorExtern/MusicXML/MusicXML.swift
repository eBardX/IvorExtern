internal import IvorMusicXML

internal struct MusicXML {

    // MARK: Internal Nested Types

    internal typealias BaseParser    = MXLParser
    internal typealias Container     = MXLContainer
    internal typealias Entity        = MXLEntity
    internal typealias MeasurePW     = MXLMeasurePW
    internal typealias MeasureTW     = MXLMeasureTW
    internal typealias MusicItem     = MXLMusicItem
    internal typealias Note          = MXLNote
    internal typealias Opus          = MXLOpus
    internal typealias PartList      = MXLPartList
    internal typealias PartPW        = MXLPartPW
    internal typealias PartTW        = MXLPartTW
    internal typealias Pitch         = MXLPitch
    internal typealias ScorePart     = MXLScorePart
    internal typealias ScorePW       = MXLScorePW
    internal typealias ScoreTW       = MXLScoreTW
    internal typealias StandardSound = MXLStandardSound
    internal typealias Work          = MXLWork

    // MARK: Internal Instance Properties

    internal let exporter = Self.Exporter()
    internal let importer = Self.Importer()
}

// MARK: - External.Exportable

extension MusicXML: External.Exportable {
}

// MARK: - External.Importable

extension MusicXML: External.Importable {
}

// MARK: - Sendable

extension MusicXML: Sendable {
}
