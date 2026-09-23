// © 2026 John Gary Pusey (see LICENSE.md)

internal import Foundation
internal import IvorModel

// MARK: Internal Functions

// Gives every unnamed part in a multi-part work a positional "Voice N"
// name (N being its 1-based position among `parts`), so an importer whose
// source format left several parts unnamed — a Guido score with no
// `\instrument` tags, say — still yields parts a listener can tell apart.
// A named part is never touched, and neither is a lone unnamed part: with
// nothing to tell it apart from, a synthesized name would only surface as
// clutter on re-export (a `V:` field the ABC exporter otherwise omits).
// Uniqueness is deliberately not enforced here — a fallback can still
// coincide with a real name — since the host application already
// uniquifies part names on import.
internal func fillEmptyPartNames<T, P>(_ parts: [Part<T, P>]) -> [Part<T, P>] {
    guard parts.count > 1
    else { return parts }

    return parts.enumerated().map { index, part in
        guard part.name.isEmpty
        else { return part }

        var part = part

        part.name = _fallbackPartName(index)

        return part
    }
}

// Whether `name` is exactly the fallback `fillEmptyPartNames` would give
// the part at `index` among `count` parts. An exporter can leave such a
// name out of its output: importing the result regenerates it from
// position anyway, and writing it would put a synthesized label into the
// file — as an instrument, in Guido's case, where `\instrument` is the
// only place a part name can go.
internal func isFallbackPartName(_ name: String,
                                 index: Int,
                                 count: Int) -> Bool {
    count > 1 && name == _fallbackPartName(index)
}

// Tidies a name read from a source file: every run of whitespace, line
// breaks and control characters (the NUL padding some MIDI tools leave in
// track names, a line break in a MusicXML `<part-name>` meant only to stack
// the label on the page) collapses to a single space, and the ends are
// trimmed.
internal func normalizeName(_ name: String) -> String {
    name.components(separatedBy: CharacterSet.whitespacesAndNewlines.union(.controlCharacters))
        .filter { !$0.isEmpty }
        .joined(separator: " ")
}

// MARK: Private Functions

private func _fallbackPartName(_ index: Int) -> String {
    "Voice \(index + 1)"
}
