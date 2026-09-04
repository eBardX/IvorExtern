// © 2026 John Gary Pusey (see LICENSE.md)

internal import IvorABC

extension ABC.Importer.MacroTable {

    // MARK: Internal Nested Types

    // A macro match found starting at some position in a symbol stream:
    // which macro matched, how many original symbols it consumed, and (for
    // a transposing macro) the note that was matched against its `n`
    // note-slot.
    internal struct Match {

        // MARK: Internal Instance Properties

        internal let consumedCount: Int
        internal let macro: ABCMacro
        internal let matchedNote: ABCNote?
    }
}
