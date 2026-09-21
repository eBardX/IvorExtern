// © 2026 John Gary Pusey (see LICENSE.md)

internal import IvorModel
internal import IvorTiming

extension MusicXML.Importer.Context {

    // A single point the walk recorded toward the part's shared, notated
    // `DynamicMap` fallback — from a `<sound>`'s own `dynamics`, a
    // `<direction>`'s notated `<dynamics>` mark, or one endpoint of a
    // `<wedge>` hairpin. `mark` carries a notated `<dynamics>` item's literal
    // text when it names no canonical `Dynamic` level — see `dynamicMark` in
    // `Extra+DynamicMap.swift`.
    internal struct DynamicEvent {

        // MARK: Internal Initializers

        internal init(beatTime: BeatTime,
                      dynamic: Dynamic,
                      kind: Kind,
                      mark: String? = nil,
                      velocity: Int? = nil) {
            self.beatTime = beatTime
            self.dynamic = dynamic
            self.kind = kind
            self.mark = mark
            self.velocity = velocity
        }

        // MARK: Internal Instance Properties

        internal let beatTime: BeatTime
        internal let dynamic: Dynamic
        internal let kind: Kind
        internal let mark: String?
        internal let velocity: Int?
    }
}

// MARK: - Sendable

extension MusicXML.Importer.Context.DynamicEvent: Sendable {
}
