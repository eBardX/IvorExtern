// © 2026 John Gary Pusey (see LICENSE.md)

internal import IvorModel
internal import IvorTuning

extension MusicXML.Importer {

    // MARK: Internal Nested Types

    // A tone the walk has read: in its voice's note table, or still waiting
    // for its tie to close (see `MusicXML.Importer.Context.pendingTies`). A
    // figure after a note goes on the first tone of its chord (see
    // `MusicXML.Importer.Context.lastChords`).
    internal enum ToneRef {
        case inserted(NoteID)
        case pending(Pitch)
    }
}

// MARK: - Sendable

extension MusicXML.Importer.ToneRef: Sendable {
}
