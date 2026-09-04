// © 2026 John Gary Pusey (see LICENSE.md)

internal import IvorModel
internal import IvorTiming

extension Guido.Importer.Context {

    // A single point the walk recorded toward the voice's `DynamicMap`, from
    // either an `\intensity` mark or one endpoint of a `\crescendo`/
    // `\diminuendo` ramp.
    internal struct DynamicEvent {

        // MARK: Internal Instance Properties

        internal let beatTime: BeatTime
        internal let dynamic: Dynamic
        internal let kind: Kind
    }
}

// MARK: - Sendable

extension Guido.Importer.Context.DynamicEvent: Sendable {
}
