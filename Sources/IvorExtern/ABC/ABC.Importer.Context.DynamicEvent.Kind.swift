// © 2026 John Gary Pusey (see LICENSE.md)

extension ABC.Importer.Context.DynamicEvent {

    // Which way a `DynamicEvent` should be rendered into a `DynamicMap`: a
    // dynamics decoration is an instant change, so it needs the
    // reassert-then-insert step every other importer's `TempoMap`/`PanMap`
    // builder uses; a hairpin's two endpoints are a single glide between
    // them, so each is inserted plainly and left for `DynamicMap`'s own
    // linear interpolation to connect.
    internal enum Kind {
        // One endpoint of a `!<(!`/`!<)!` or `!>(!`/`!>)!` hairpin.
        case rampBoundary

        // An instant change — a dynamics decoration such as `!mf!`.
        case step
    }
}

// MARK: - Sendable

extension ABC.Importer.Context.DynamicEvent.Kind: Sendable {
}
