// © 2026 John Gary Pusey (see LICENSE.md)

internal import IvorModel
internal import IvorTiming

extension Guido.Importer.Context {

    // A single point the walk recorded toward the voice's `DynamicMap`, from
    // either an `\intensity` mark or one endpoint of a `\crescendo`/
    // `\diminuendo` ramp. `mark` carries an `\intensity` tag's literal type
    // text when it names no canonical `Dynamic` level — see `dynamicMark` in
    // `Extra+DynamicMap.swift`.
    internal struct DynamicEvent {

        // MARK: Internal Initializers

        internal init(beatTime: BeatTime,
                      dynamic: Dynamic,
                      kind: Kind,
                      mark: String? = nil) {
            self.beatTime = beatTime
            self.dynamic = dynamic
            self.kind = kind
            self.mark = mark
        }

        // MARK: Internal Instance Properties

        internal let beatTime: BeatTime
        internal let dynamic: Dynamic
        internal let kind: Kind
        internal let mark: String?
    }
}

// MARK: - Sendable

extension Guido.Importer.Context.DynamicEvent: Sendable {
}
