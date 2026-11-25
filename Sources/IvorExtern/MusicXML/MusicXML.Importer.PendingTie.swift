// © 2026 John Gary Pusey (see LICENSE.md)

internal import IvorModel
internal import IvorTiming
internal import IvorTuning
internal import XestiTools

extension MusicXML.Importer {

    // MARK: Internal Nested Types

    // A tied note not yet in its voice's note table: it gathers duration
    // until a tie stop of the same pitch closes it, or the voice ends (see
    // `MusicXML.Importer.Context.pendingTies`).
    internal struct PendingTie {

        // MARK: Internal Instance Properties

        internal var attack: BeatTime
        internal var duration: BeatDuration
        internal var extras: Extras?
        internal var ornamentation: NoteTable<BeatTime, Pitch>.Ornamentation?
    }
}

// MARK: - Sendable

extension MusicXML.Importer.PendingTie: Sendable {
}
