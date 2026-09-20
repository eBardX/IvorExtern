// © 2026 John Gary Pusey (see LICENSE.md)

internal import IvorModel
internal import IvorTiming

extension ABC.Importer.Context {

    // A single point the walk recorded toward the voice's `DynamicMap`, from
    // either a dynamics decoration (`!mf!`, `!ff!`, …) or one endpoint of a
    // `!<(!`/`!<)!` (crescendo) or `!>(!`/`!>)!` (diminuendo) hairpin. `mark`
    // carries a decoration's literal name when it names no canonical
    // `Dynamic` level — see `dynamicMark` in `Extra+DynamicMap.swift`.
    internal struct DynamicEvent {

        // MARK: Internal Instance Properties

        internal let beatTime: BeatTime
        internal let dynamic: Dynamic
        internal let kind: Kind
        internal let mark: String?

        internal init(beatTime: BeatTime,
                      dynamic: Dynamic,
                      kind: Kind,
                      mark: String? = nil) {
            self.beatTime = beatTime
            self.dynamic = dynamic
            self.kind = kind
            self.mark = mark
        }
    }
}

// MARK: - Sendable

extension ABC.Importer.Context.DynamicEvent: Sendable {
}
