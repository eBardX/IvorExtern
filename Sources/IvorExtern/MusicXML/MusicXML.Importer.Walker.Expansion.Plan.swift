// © 2026 John Gary Pusey (see LICENSE.md)

internal import IvorMXL

extension MusicXML.Importer.Walker.Expansion {

    // MARK: Internal Nested Types

    internal enum Plan {
        case items([MXLMusicItem])
        case syntheticRest
    }
}
