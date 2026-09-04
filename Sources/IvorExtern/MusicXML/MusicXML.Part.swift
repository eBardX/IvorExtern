// © 2026 John Gary Pusey (see LICENSE.md)

private import IvorMusicXML

// A single walked part: its retained `<score-part>` metadata plus the voices
// resolved from its measures, sorted by voice ID (see
// `Importer.Walker._voices(from:)`).
extension MusicXML {
    internal struct Part {

        // MARK: Internal Initializers

        internal init(part: MusicXML.ScorePart,
                      voices: [Voice]) {
            self.part = part
            self.voices = voices
        }

        // MARK: Internal Instance Properties

        internal let part: MusicXML.ScorePart
        internal let voices: [Voice]
    }
}

// MARK: - Sendable

extension MusicXML.Part: Sendable {
}
