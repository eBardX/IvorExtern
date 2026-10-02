// © 2026 John Gary Pusey (see LICENSE.md)

internal import IvorModel

private import XestiTools

// Roles outside `Credit.Role`'s three standard constants that more than one
// format names: ABC `Z:` and MusicXML `<encoder>` both credit a
// `transcriber`, ABC `Z:abc-edited-by` an `editor`, and SMF RP-026
// `{#Artist=}` an `artist`.
extension Credit.Role {

    // MARK: Internal Type Properties

    internal static let artist      = Self("artist")
    internal static let editor      = Self("editor")
    internal static let transcriber = Self("transcriber")
}
