// © 2026 John Gary Pusey (see LICENSE.md)

internal import IvorModel
internal import IvorTiming

extension MusicXML.Importer.Context {

    // A single point the walk recorded toward the part's shared, notated
    // `DynamicMap` fallback — from a `<sound>`'s own `dynamics`, a
    // `<direction>`'s notated `<dynamics>` mark, or one endpoint of a
    // `<wedge>` hairpin.
    internal struct DynamicEvent {

        // MARK: Internal Instance Properties

        internal let beatTime: BeatTime
        internal let dynamic: Dynamic
        internal let kind: Kind
    }
}

// MARK: - Sendable

extension MusicXML.Importer.Context.DynamicEvent: Sendable {
}
