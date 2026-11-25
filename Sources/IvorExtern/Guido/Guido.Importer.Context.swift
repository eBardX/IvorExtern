// © 2025–2026 John Gary Pusey (see LICENSE.md)

internal import IvorGMN
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
// summed duration rather than two. `heldTies` holds each flushed tone tied
// to whatever follows — every tone of a note or chord a bare `\tieEnd`
// follows, or one chord tone a `\tieBegin` marks (the indices in
// `pendingTiedIndices`) — not yet in `noteTable`: the next note or chord
// continues it with a tone of the same pitch, or it ends where it was
// written (see `HeldTies`). `tempoEvents` collects every `\tempo`
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
//
// `instrumentName` is the name of the first `\instrument` tag the walk
// reaches, for the importer to name the part with — read here rather than
// off the pre-walk AST, since only the walk splices each `$variable`'s
// symbols into place, and an `\instrument` tag inside one is otherwise
// invisible.
//
// `barlines` holds one entry per bar start while a meter is in force: one
// at every `\meter` tag (with its `meterSymbol`), and one at every `\bar`
// — what `makeMeterTable(_:)` builds the work's meter table from. `meter`
// is the meter in force, from the last `\meter` tag the walk read.
//
// `keyEvents` holds each `\key` tag as it's met, with the key
// `convertToKey(_:)` gives it — what `makeKeyTable(_:)` builds the work's
// key table from. A key it can't represent is left out.
//
// The ornament tags read so far shape the ornaments of the next note or
// chord (see `Guido.Importer.Ornaments`): `activeOrnamentTags` are the
// ornament, tremolo, roll and fermata tags whose range the walk is inside
// (a tag's body, or a `\trillBegin` … `\trillEnd` span), applying to every
// note or chord in it; `stagedOrnamentTags` are bodiless ones waiting for
// the next note or chord, cleared at a rest or bar line; and `stagedGrace`
// is the grace figure read since the last note or chord. The pending note
// keeps its ornaments until it goes into `noteTable`. `markTable` holds the
// fermatas on rests and bar lines, and `lastEvent` the span of the last
// note, chord or rest, which a fermata on a bar line spans.
// `nextArpeggioGroup` numbers each rolled chord, across every voice of the
// score, and `warningCounts` counts what the walk dropped.
extension Guido.Importer {

    // MARK: Internal Nested Types

    internal struct Context {

        // MARK: Internal Instance Properties

        internal var activeOrnamentTags: [GMNTag] = []
        internal var barlines: [(beatTime: BeatTime, meter: Meter, extras: Extras?)] = []
        internal var currentBeatTime: BeatTime = .zero
        internal var dynamicEvents: [DynamicEvent] = []
        internal var heldTies = HeldTies()
        internal var instrumentEvents: [(beatTime: BeatTime, instrument: Instrument, tag: GMNInstrument)] = []
        internal var instrumentName: String?
        internal var keyEvents: [(beatTime: BeatTime, key: Key)] = []
        internal var lastDuration: Guido.Duration = Self.defaultDuration
        internal var lastDynamic: Dynamic = .mp
        internal var lastEvent: (attack: BeatTime, duration: BeatDuration)?
        internal var lastOctave: GMNPitch.Octave = Self.defaultOctave
        internal var markTable = PartMarkTable<BeatTime>()
        internal var meter: Meter?
        internal var nextArpeggioGroup: UInt = 1
        internal var noteTable: NoteTable<BeatTime, Pitch> = NoteTable()
        internal var pendingDynamicRamps: [GMNTag.Ident?: (beatTime: BeatTime, dynamic: Dynamic, direction: GMNDynamicRamp.Direction)] = [:]
        internal var pendingNote: Guido.Importer.PendingNote?
        internal var pendingNoteExtras: [Extra] = []
        internal var pendingTiedIndices: Set<Int> = []
        internal var stagedGrace: NoteTable<BeatTime, Pitch>.GraceFigure?
        internal var stagedOrnamentTags: [GMNTag] = []
        internal var sustainTable: PedalTable<BeatTime> = PedalTable()
        internal var tempoEvents: [(beatTime: BeatTime, tempo: Tempo, text: String?)] = []
        internal var tieArmed = false
        internal var warningCounts: [ExternWarning.Kind: Int] = [:]
    }
}

// MARK: -

extension Guido.Importer.Context {

    // MARK: Internal Instance Methods

    // A fermata mark over `span` from `attack` (resolution 4 of the
    // grace-notes plan); nothing for an empty span.
    internal mutating func addFermataMark(at attack: BeatTime,
                                          span: BeatDuration,
                                          shape: FermataShape) {
        guard let span = PositiveDuration(span)
        else { return }

        markTable.insert(time: attack,
                         mark: .fermata(Fermata(shape: shape), span: span))
    }

    internal mutating func advance(_ duration: BeatDuration) {
        currentBeatTime += duration
    }

    // `tiedIndices` are the tones of `notes` a `\tieBegin` marks as tied to
    // whatever follows (see `Guido.Importer.Walker`). A note or chord tied
    // to the pending one merges into it, adding what its own `ornaments`
    // have that the pending note's don't; any other is pending in turn,
    // with a new arpeggio group if it's rolled.
    internal mutating func considerTie(_ notes: [Guido.Note],
                                       tiedIndices: Set<Int> = [],
                                       attackTime: BeatTime,
                                       ornaments: Guido.Importer.Ornaments = .init()) throws(Guido.Error) {
        if tieArmed,
           var pending = pendingNote,
           Self._pitchesMatch(pending.notes, notes) {
            var later = ornaments

            later.arpeggio = nil
            later.isArpeggiated = false
            pending.ornaments.absorb(later)

            pending.notes = zip(pending.notes, notes).map {
                Guido.Note(duration: Guido.Duration(numberValue: $0.duration.numberValue + $1.duration.numberValue),
                           pitch: $0.pitch)
            }
            pendingNote = pending
        } else {
            var ornaments = ornaments

            if ornaments.isArpeggiated {
                ornaments.arpeggio = ArpeggioGroup(uintValue: nextArpeggioGroup)
                nextArpeggioGroup += 1
            }

            try flushPendingNote()
            pendingNote = Guido.Importer.PendingNote(attackTime: attackTime,
                                                     extras: pendingNoteExtras,
                                                     notes: notes,
                                                     ornaments: ornaments)
            pendingNoteExtras = []
        }

        if let pending = pendingNote {
            lastEvent = (attack: pending.attackTime,
                         duration: pending.notes.map { convertToBeatDuration($0.duration) }.max() ?? .zero)
        }

        pendingTiedIndices = tiedIndices
        tieArmed = false
    }

    // Each tone is tied on its own (see `heldTies`): all of them by a bare
    // `\tieEnd` after them, while `tieArmed`, or one by a `\tieBegin` in its
    // chord segment. A note or chord tied as a whole to a matching one has
    // already merged with it (see `considerTie(_:tiedIndices:attackTime:)`),
    // so this is what keeps a tie on one tone of a chord
    // (`{ \tieBegin:1 c, e } { c \tieEnd:1, g }`), or one that a tag
    // interrupts.
    internal mutating func flushPendingNote() throws(Guido.Error) {
        guard let pending = pendingNote
        else { return }

        let extras: Extras? = pending.extras.isEmpty ? nil : Extras(elements: pending.extras)
        var pitches: [Int: Pitch] = [:]
        var tones: [HeldTies.Tone] = []

        for (index, note) in pending.notes.enumerated() where note.pitch.name != .empty {
            pitches[index] = try convertToStandardPitch(note.pitch)
        }

        let lowestIndex = pitches.min { ($0.value, $0.key) < ($1.value, $1.key) }?.key

        for (index, note) in pending.notes.enumerated() {
            guard let pitch = pitches[index]
            else { continue }

            tones.append(HeldTies.Tone(attack: pending.attackTime,
                                       duration: convertToBeatDuration(note.duration),
                                       extras: extras,
                                       isTied: tieArmed || pendingTiedIndices.contains(index),
                                       ornamentation: pending.ornaments.ornamentation(pitch: pitch,
                                                                                      isLowest: index == lowestIndex),
                                       pitch: pitch))
        }

        heldTies.commit(tones, into: &noteTable)
        pendingNote = nil
        pendingTiedIndices = []
    }

    // Records the key of a `\key` tag here (see `keyEvents`).
    internal mutating func recordKey(_ gmnKey: GMNKey) {
        guard let key = convertToKey(gmnKey)
        else { return }

        keyEvents.append((beatTime: currentBeatTime,
                          key: key))
    }

    // Records a `\meter` tag here: it's the meter in force from now on, and
    // starts a bar (see `barlines`).
    internal mutating func recordMeter(_ meter: GMNMeter) {
        guard let converted = convertToMeter(meter)
        else { return }

        self.meter = converted

        barlines.append((currentBeatTime, converted, convertToMeterExtras(meter)))
    }

    // MARK: Private Type Properties

    private static let defaultDuration = Guido.Duration(numberValue: Number(numerator: 1,
                                                                            denominator: 4))
    private static let defaultOctave = GMNPitch.Octave(intValue: 1).require()

    // MARK: Private Type Methods

    private static func _pitchesMatch(_ lhs: [Guido.Note],
                                      _ rhs: [Guido.Note]) -> Bool {
        lhs.count == rhs.count && zip(lhs, rhs).allSatisfy { $0.pitch == $1.pitch }
    }
}

// MARK: - Sendable

extension Guido.Importer.Context: Sendable {
}
