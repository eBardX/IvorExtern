// © 2026 John Gary Pusey (see LICENSE.md)

internal import IvorModel
internal import IvorMXL
internal import IvorTiming
internal import IvorTuning

extension MusicXML.Importer {

    // MARK: Internal Nested Types

    // What one note's `<notations>` say about its ornamentation and the marks
    // around it (see `MusicXML.Importer.Walker.noteMarks(_:written:transpose:_:)`):
    // its trill or mordent, its tremolo (single, unmeasured, or a two-note
    // tremolo's start or stop), its roll, its fermata, a caesura after it, and the wavy lines and
    // slurs it starts or stops.
    internal struct NoteMarks {

        // MARK: Internal Instance Properties

        internal var arpeggioDirection: ArpeggioDirection?
        internal var arpeggioNumber: UInt = 0
        internal var fermata: FermataShape?
        internal var hasCaesura = false
        internal var hasNonArpeggiate = false
        internal var isArpeggiated = false
        internal var ornament: NoteTable<BeatTime, Pitch>.Ornament?
        internal var slurStops: [UInt] = []
        internal var tremolo: MXLTremolo?
        internal var wavyLineStarts: [UInt] = []
        internal var wavyLineStops: [UInt] = []
    }
}

// MARK: - Sendable

extension MusicXML.Importer.NoteMarks: Sendable {
}
