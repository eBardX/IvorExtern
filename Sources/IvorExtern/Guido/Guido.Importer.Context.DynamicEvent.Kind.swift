// © 2026 John Gary Pusey (see LICENSE.md)

extension Guido.Importer.Context.DynamicEvent {

    // Which way a `DynamicEvent` should be rendered into a `DynamicMap`: an
    // `\intensity` mark is an instant change, so it needs the reassert-then-
    // insert step every other importer's `TempoMap`/`PanMap` builder uses; a
    // ramp's two endpoints are a single glide between them, so each is
    // inserted plainly and left for `DynamicMap`'s own linear interpolation
    // to connect.
    internal enum Kind {
        // One endpoint of a `\crescendo`/`\diminuendo` ramp.
        case rampBoundary

        // An instant change — an `\intensity` mark.
        case step
    }
}

// MARK: - Sendable

extension Guido.Importer.Context.DynamicEvent.Kind: Sendable {
}
