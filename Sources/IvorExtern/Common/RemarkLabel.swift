// © 2026 John Gary Pusey (see LICENSE.md)

// The `Remark.label` values the importers give the descriptive text fields
// that have no dedicated home in `Work.Metadata`, and that the exporters
// map back onto those fields. Sharing them is what lets
// a remark cross formats intact: ABC `S:` and MusicXML `<source>` both
// read and write `source`, so a source note imported from one is exported
// to the other's own field rather than to a generic fallback.
internal enum RemarkLabel {

    // MARK: Internal Type Properties

    internal static let area                = "area"
    internal static let book                = "book"
    internal static let discography         = "discography"
    internal static let encodingDescription = "encoding description"
    internal static let fileURL             = "file URL"
    internal static let footer              = "footer"
    internal static let group               = "group"
    internal static let history             = "history"
    internal static let label               = "label"
    internal static let movementNumber      = "movement number"
    internal static let notes               = "notes"
    internal static let origin              = "origin"
    internal static let relation            = "relation"
    internal static let rhythm              = "rhythm"
    internal static let source              = "source"
    internal static let workNumber          = "work number"
}
