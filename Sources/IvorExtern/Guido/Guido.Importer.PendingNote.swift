// © 2026 John Gary Pusey (see LICENSE.md)

internal import IvorModel
internal import IvorTiming
internal import XestiTools

extension Guido.Importer {

    // MARK: Internal Nested Types

    // A note or chord the walk has read but not yet put into the note table,
    // since whatever follows may still tie onto it (see
    // `Guido.Importer.Context.considerTie(_:tiedIndices:attackTime:ornaments:)`):
    // its attack, its notes, the extras of its marks, and its ornaments.
    internal struct PendingNote {

        // MARK: Internal Instance Properties

        internal var attackTime: BeatTime
        internal var extras: [Extra]
        internal var notes: [Guido.Note]
        internal var ornaments: Guido.Importer.Ornaments
    }
}

// MARK: - Sendable

extension Guido.Importer.PendingNote: Sendable {
}
