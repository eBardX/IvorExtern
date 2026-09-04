// © 2026 John Gary Pusey (see LICENSE.md)

extension MusicXML.Importer.Context.DynamicEvent {

    // Which way a `DynamicEvent` should be rendered into a `DynamicMap`: a
    // `<sound>`'s `dynamics` or a notated `<dynamics>` mark is an instant
    // change, so it needs the reassert-then-insert step every other
    // importer's `TempoMap`/`PanMap` builder uses; a `<wedge>`'s two
    // endpoints are a single glide between them, so each is inserted
    // plainly and left for `DynamicMap`'s own linear interpolation to
    // connect.
    internal enum Kind {
        // One endpoint of a `<wedge>` hairpin.
        case rampBoundary

        // An instant change — a `<sound>`'s `dynamics` or a notated
        // `<dynamics>` mark.
        case step
    }
}

// MARK: - Sendable

extension MusicXML.Importer.Context.DynamicEvent.Kind: Sendable {
}
