// © 2025–2026 John Gary Pusey (see LICENSE.md)

internal import IvorGuido
internal import IvorModel
internal import IvorTiming
internal import IvorTuning
internal import XestiNumbers
internal import XestiTools

// The inheritance replay migrated into the walk itself:
// `lastDuration`/`lastOctave` are reused whenever a note/rest omits its own,
// mirroring guidolib's own sticky-state reset per voice. `pendingNote` and
// `tieArmed` are this type's own addition — the walk defers committing a
// just-built note/chord to `noteTable` until it knows whether the very next symbol
// ties onto it, since a tied pair collapses into a single table entry with
// summed duration rather than two. `tempoEvents` collects every `\tempo`
// tag's resolved beats-per-minute, in source order, for the importer to
// fold into a `TempoMap` once every voice has been walked.
//
// `dynamicEvents` collects both `\intensity` marks and the two endpoints of
// every `\crescendo`/`\diminuendo` ramp, tagged by `DynamicEvent.Kind` so the
// importer's `DynamicMap` builder knows which points should read as an
// instant step (an `\intensity` mark) and which should read as a smooth
// glide (a ramp's two endpoints) — `Kind`'s own comment has the detail.
// `lastDynamic` is the dynamic level in effect as of the most recently
// processed mark or ramp endpoint, used both as a ramp's implicit starting
// level and as the level a ramp shifts one step from when it has no explicit
// target (`GMNDynamicRamp` carries a direction, not a level).
// `pendingDynamicRamps`, keyed by a ramp's optional `GMNTag.Ident` exactly as
// guidolib itself pairs `\crescBegin`/`\crescEnd`-style spans, holds an open
// ramp's starting beat, level, and direction until its matching close.
extension Guido.Importer {

    // MARK: Internal Nested Types

    internal struct Context {

        // MARK: Internal Instance Properties

        internal var currentBeatTime: BeatTime = .zero
        internal var dynamicEvents: [DynamicEvent] = []
        internal var instrumentEvents: [(beatTime: BeatTime, instrument: Instrument)] = []
        internal var lastDuration: Guido.Duration = Self.defaultDuration
        internal var lastDynamic: Dynamic = .mp
        internal var lastOctave: GMNPitch.Octave = Self.defaultOctave
        internal var noteTable: NoteTable<BeatTime, Pitch> = NoteTable()
        internal var pendingDynamicRamps: [GMNTag.Ident?: (beatTime: BeatTime, dynamic: Dynamic, direction: GMNDynamicRamp.Direction)] = [:]
        internal var pendingNote: (attackTime: BeatTime, notes: [Guido.Note])?
        internal var tempoEvents: [(beatTime: BeatTime, tempo: Tempo)] = []
        internal var tieArmed = false
    }
}

// MARK: -

extension Guido.Importer.Context {

    // MARK: Internal Instance Methods

    internal mutating func advance(_ duration: BeatDuration) {
        currentBeatTime += duration
    }

    // MARK: Private Type Properties

    private static let defaultDuration = Guido.Duration(numberValue: Number(numerator: 1,
                                                                            denominator: 4))
    private static let defaultOctave = GMNPitch.Octave(intValue: 1).require()
}

// MARK: - Sendable

extension Guido.Importer.Context: Sendable {
}
