// © 2026 John Gary Pusey (see LICENSE.md)

internal import IvorModel
internal import IvorTiming

extension ABC.Importer.Context {

    // A single point the walk recorded toward the voice's `DynamicMap`, from
    // either a dynamics decoration (`!mf!`, `!ff!`, …) or one endpoint of a
    // `!<(!`/`!<)!` (crescendo) or `!>(!`/`!>)!` (diminuendo) hairpin.
    internal struct DynamicEvent {

        // MARK: Internal Instance Properties

        internal let beatTime: BeatTime
        internal let dynamic: Dynamic
        internal let kind: Kind
    }
}

// MARK: - Sendable

extension ABC.Importer.Context.DynamicEvent: Sendable {
}
