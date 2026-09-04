// © 2026 John Gary Pusey (see LICENSE.md)

internal import IvorModel
internal import IvorTiming
internal import IvorTuning

// A single voice within a walked `Part`, already fully resolved: ties and
// chord folding happen inline during the walk (see `Importer.Walker`), so a
// voice carries its finished note table directly rather than an intermediate
// event stream to coalesce afterward. `noteDynamicEvents` — each of this
// voice's own notes that carried an explicit `dynamics` (velocity)
// attribute — is similarly pre-resolved to this voice, unlike the part-wide
// `tempoEvents`/`panEvents`/direction-dynamics `Importer.Walker.WalkResult`
// carries alongside it.
extension MusicXML {
    internal struct Voice {

        // MARK: Internal Initializers

        internal init(id: String?,
                      noteDynamicEvents: [(beatTime: BeatTime, dynamic: Dynamic)] = [],
                      noteTable: NoteTable<BeatTime, IvorTuning.Pitch>) {
            self.id = id
            self.noteDynamicEvents = noteDynamicEvents
            self.noteTable = noteTable
        }

        // MARK: Internal Instance Properties

        // The `<voice>` identifier, or `nil` for the implicit single voice of
        // a part that never declares one.
        internal let id: String?
        internal let noteDynamicEvents: [(beatTime: BeatTime, dynamic: Dynamic)]
        internal let noteTable: NoteTable<BeatTime, IvorTuning.Pitch>
    }
}

// MARK: - Sendable

extension MusicXML.Voice: Sendable {
}
