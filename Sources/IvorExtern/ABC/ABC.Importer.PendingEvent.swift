// © 2026 John Gary Pusey (see LICENSE.md)

internal import IvorModel
internal import IvorTiming
internal import XestiTools

extension ABC.Importer {

    // MARK: Internal Nested Types

    //
    // A note, chord or rest the walker has built but not yet committed (see
    // `ABC.Importer.Context.pendingEvent`): its attack, the event, its extras, and its
    // ornaments.
    //
    internal struct PendingEvent {

        // MARK: Internal Instance Properties

        internal var attack: BeatTime
        internal var event: ABC.Event
        internal var extras: [Extra]
        internal var ornaments: ABC.Importer.Ornaments
    }
}

// MARK: - Sendable

extension ABC.Importer.PendingEvent: Sendable {
}
