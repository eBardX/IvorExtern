// © 2026 John Gary Pusey (see LICENSE.md)

internal import IvorModel
internal import IvorMusicXML
internal import IvorTiming
internal import IvorTuning

// The running resolution scope threaded through one part's walk, across every
// measure the `Plan` visits (a measure may be visited more than once, for a
// repeat). `activeDivisions`/`times`/`transposes` mirror `<attributes>`
// inheritance, replayed live as `<attributes>` items are encountered — the
// same values every time a given measure is (re-)visited, since a repeat
// replays that measure's own `<attributes>` items verbatim. `cursor` is
// relative to `measureStart` and resets every measure visit; `lastDuration`
// is the previous non-chord note's (or rest's) length, used to back-date a
// folded chord tone's onset to its lead note's; `measureAdvance` is the
// furthest position any voice reached during the current measure visit.
//
// `noteTables`/`pendingTies`/`voiceIDs` are keyed by the MusicXML `<voice>`
// identifier (`nil` for a part's implicit, undeclared voice) — one Ivor `Part`
// results per key, in first-appearance order. A tied note is not inserted
// immediately: its entry in `pendingTies` accumulates duration until a
// matching (by sounding pitch) tie-stop note closes it, or the voice ends,
// mirroring the walker shape used by every other format's importer.
//
// `noteDynamicEvents`, keyed the same way, collects each note's own
// `dynamics` attribute (a MIDI-style velocity), while `directionDynamicEvents`
// collects each `<direction>`'s and bare `<sound>`'s own dynamic — a
// `<sound>`'s own `dynamics` attribute (also MIDI-style) when present,
// falling back to that direction's notated, visual-only `<dynamics>` mark or
// a `<wedge>` hairpin endpoint — those aren't tied to any one voice, so
// they're part-wide like `tempoEvents`/`panEvents`. Each event's own `Kind`
// says whether it should read as an instant step or, for a wedge endpoint,
// glide smoothly to the next — see `DynamicEvent.Kind`'s own comment. The
// importer prefers a voice's own `noteDynamicEvents` when it has any and
// falls back to `directionDynamicEvents` otherwise — see
// `MusicXML.Importer._makeDynamicMap`.
//
// `lastDirectionDynamic` is the dynamic level in effect as of the most
// recently recorded `directionDynamicEvents` entry, used as a wedge's
// implicit starting level and as the level a wedge shifts one step from
// when it has no explicit target dynamic written after it — `<wedge>`
// carries only a crescendo/diminuendo direction, not a level.
// `pendingWedges`, keyed by a wedge's optional `number` exactly as
// MusicXML itself distinguishes concurrent wedges, holds an open wedge's
// starting beat, level, and kind (`.crescendo`/`.diminuendo`) until its
// matching `.stop`.
extension MusicXML.Importer {

    internal struct Context {

        // MARK: Internal Instance Properties

        internal var activeDivisions: Int?
        internal var cursor: MusicXML.Duration = .zero
        internal var directionDynamicEvents: [DynamicEvent] = []
        internal var lastDirectionDynamic: Dynamic = .mp
        internal var lastDuration: MusicXML.Duration = .zero
        internal var measureAdvance: MusicXML.Duration = .zero
        internal var measureStart: MusicXML.Duration = .zero
        internal var noteDynamicEvents: [String?: [(beatTime: BeatTime, dynamic: Dynamic)]] = [:]
        internal var noteTables: [String?: NoteTable<BeatTime, IvorTuning.Pitch>] = [:]
        internal var panEvents: [(beatTime: BeatTime, pan: Pan)] = []
        internal var pendingTies: [String?: [IvorTuning.Pitch: (attack: BeatTime, duration: BeatDuration)]] = [:]
        internal var pendingWedges: [MXLNumberLevel?: (beatTime: BeatTime, dynamic: Dynamic, kind: MXLWedge.Kind)] = [:]
        internal var tempoEvents: [(beatTime: BeatTime, tempo: Tempo)] = []
        internal var times: [UInt?: MXLTime] = [:]
        internal var transposes: [UInt?: MXLTranspose] = [:]
        internal var voiceIDs: [String?] = []
    }
}

// MARK: -

extension MusicXML.Importer.Context {

    // MARK: Internal Instance Methods

    internal mutating func advance(_ duration: MusicXML.Duration) {
        cursor += duration

        if measureAdvance < cursor {
            measureAdvance = cursor
        }
    }

    // Registers `id` as a voice this part carries, in first-appearance order,
    // and returns its note table for mutation.
    internal mutating func noteTable(forVoice id: String?) -> NoteTable<BeatTime, IvorTuning.Pitch> {
        if !voiceIDs.contains(id) {
            voiceIDs.append(id)
        }

        return noteTables[id] ?? NoteTable()
    }
}

// MARK: - Sendable

extension MusicXML.Importer.Context: Sendable {
}
