// © 2026 John Gary Pusey (see LICENSE.md)

internal import IvorModel
internal import IvorTiming
internal import IvorTuning
internal import XestiTools

extension MusicXML.Importer {

    // MARK: Internal Nested Types

    // The first note of a two-note tremolo (`<tremolo type="start">`), held
    // until the note that stops it: the two become one note as long as both,
    // with the second as its partner (resolution 15 of the grace-notes plan).
    internal struct PendingTremolo {

        // MARK: Internal Instance Properties

        internal let attack: BeatTime
        internal let duration: BeatDuration
        internal let extras: Extras?
        internal let ornamentation: NoteTable<BeatTime, Pitch>.Ornamentation?
        internal let pitch: Pitch
        internal let strokes: TremoloStrokes
    }
}

// MARK: - Sendable

extension MusicXML.Importer.PendingTremolo: Sendable {
}
