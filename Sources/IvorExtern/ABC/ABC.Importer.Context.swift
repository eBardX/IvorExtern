// © 2025–2026 John Gary Pusey (see LICENSE.md)

internal import IvorABC
internal import IvorModel
internal import IvorTiming
internal import IvorTuning

// The running resolution state threaded through one voice's walk, replacing
// upstream's own resolution scope (macros, key/bar accidentals, meter, unit
// note length, pending tuplet/broken-rhythm scaling) and its sounding-pitch
// pass's active-clef tracking, all in one place, since nothing here is
// voice-agnostic the way upstream's split across two passes was — each
// voice gets its own fresh `Context`.
//
// `pendingEvent`/`tieArmed` are this type's own addition: the walk defers
// committing a just-built note/chord/rest to `noteTable` until it knows
// whether the very next item is a broken-rhythm marker (which rescales it in
// place) or a tie continuation (which merges into it) — see
// `ABC.Importer.Walker`. `tempoEvents` collects every `Q:` field's resolved
// beats-per-minute, in source order, for the importer to fold into a
// `TempoMap` once every voice has been walked.
//
// `dynamicEvents` collects both dynamics decorations (`!mf!`, `!ff!`, …) and
// the two endpoints of every crescendo/diminuendo hairpin, tagged by
// `DynamicEvent.Kind` so the importer's `DynamicMap` builder knows which
// points should read as an instant step (a decoration) and which should read
// as a smooth glide (a hairpin's two endpoints) — `Kind`'s own comment has
// the detail. `lastDynamic` is the dynamic level in effect as of the most
// recently processed mark or hairpin endpoint, used both as a hairpin's
// implicit starting level and as the level a hairpin shifts one step from
// when it has no explicit target dynamic written after it.
// `pendingCrescendo`/`pendingDiminuendo` hold an open hairpin's starting beat
// and level until its matching close — ABC decorations carry no identifier
// to pair by, so (unlike Guido's `\crescBegin`/`\crescEnd`) at most one
// hairpin of each direction can be open at a time.
extension ABC.Importer {

    // MARK: Internal Nested Types

    internal struct Context {

        // MARK: Internal Initializers

        internal init(unitNoteLength: (numerator: UInt, denominator: UInt) = (1, 8)) {
            self.unitNoteLength = unitNoteLength
        }

        // MARK: Internal Instance Properties

        internal var activeClef: ABCClef?
        internal var barAccidentals: [ABCPitch.Letter: ABCPitch.Accidental] = [:]
        internal var currentBeatTime: BeatTime = .zero
        internal var dynamicEvents: [DynamicEvent] = []
        internal var hasExplicitUnitNoteLength = false
        internal var keyAccidentals: [ABCPitch.Letter: ABCPitch.Accidental] = [:]
        internal var lastDynamic: Dynamic = .mp
        internal var macros: [ABCMacro] = []
        internal var meter: ABCTimeSignature?
        internal var noteTable: NoteTable<BeatTime, Pitch> = NoteTable()
        internal var pendingBrokenRhythmRight: (numerator: UInt, denominator: UInt)?
        internal var pendingCrescendo: (beatTime: BeatTime, dynamic: Dynamic)?
        internal var pendingDiminuendo: (beatTime: BeatTime, dynamic: Dynamic)?
        internal var pendingEvent: (attack: BeatTime, event: ABC.Event)?
        internal var pendingTuplet: (beatCount: UInt, noteCount: UInt, remainingCount: UInt)?
        internal var tempoEvents: [(beatTime: BeatTime, tempo: Tempo)] = []
        internal var tieArmed = false
        internal var unitNoteLength: (numerator: UInt, denominator: UInt)
    }
}

// MARK: -

extension ABC.Importer.Context {

    // MARK: Internal Instance Methods

    internal mutating func advance(_ duration: BeatDuration) {
        currentBeatTime += duration
    }
}

// MARK: - Sendable

extension ABC.Importer.Context: Sendable {
}
