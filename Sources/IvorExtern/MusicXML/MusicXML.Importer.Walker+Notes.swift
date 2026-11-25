// © 2026 John Gary Pusey (see LICENSE.md)

internal import IvorModel
internal import IvorMXL
internal import IvorTiming
internal import IvorTuning
internal import XestiTools

// Putting one regular tone into its voice's note table, with its
// ornamentation: the grace run before it, its trill, mordent or tremolo (or
// the trill of an open wavy line), its roll and its fermata. A two-note
// tremolo's first note waits for the note that stops it, and a tied tone
// for the tone that ends its tie (see `MusicXML.Importer.Context`).
extension MusicXML.Importer.Walker {

    // MARK: Internal Type Methods

    // Every tie still open when the part ends ends where it was written.
    internal static func flushPendingTies(_ context: inout MusicXML.Importer.Context) {
        for (voiceID, pending) in context.pendingTies {
            for (pitch, entry) in pending {
                context.noteTables[voiceID, default: NoteTable()].insertImported(attack: entry.attack,
                                                                                 duration: entry.duration,
                                                                                 pitch: pitch,
                                                                                 extras: entry.extras,
                                                                                 ornamentation: entry.ornamentation)
            }
        }

        context.pendingTies = [:]
    }

    // MARK: Internal Instance Methods

    // Inserts one regular tone, `pitch`, written as `written`: a chord's
    // first tone, or (if `isChordTone`) a later one, which shares that
    // tone's attack and duration.
    internal func insertTone(_ note: MXLNote,
                             pitch: Pitch,
                             written: MXLPitch,
                             attack: BeatTime,
                             duration: BeatDuration,
                             tie: [MXLTie],
                             isChordTone: Bool,
                             _ context: inout MusicXML.Importer.Context) {
        let voiceID = note.voice?.voice
        let marks = noteMarks(note,
                              written: written,
                              transpose: Self.activeTranspose(for: note, in: context),
                              &context)
        let extras = Self.noteExtras(note)

        if let pending = context.pendingTremolos[voiceID] {
            if !isChordTone, marks.tremolo?.kind == .stop {
                Self._joinTwoNoteTremolo(pending, partner: pitch, duration: duration, voiceID: voiceID, &context)

                return
            }

            Self.flushPendingTremolo(voiceID: voiceID, &context)
        }

        var graceBefore: NoteTable<BeatTime, Pitch>.GraceFigure?

        if !isChordTone,
           let run = context.graceRuns.removeValue(forKey: voiceID),
           !(run.followsPrevious && Self.attachGraceAfter(run, voiceID: voiceID, &context)) {
            graceBefore = run.figure(isAfter: false, mainDuration: duration)
        }

        let ornamentation = Self.nonEmpty(.init(graceBefore: graceBefore,
                                                ornament: Self._ornament(marks, note: note, duration: duration, voiceID: voiceID, &context),
                                                arpeggio: Self._arpeggio(marks, attack: attack, &context),
                                                fermata: marks.fermata.map { Fermata(shape: $0) }))

        if !isChordTone,
           let tremolo = marks.tremolo,
           tremolo.kind == .start,
           let strokes = Self._strokes(tremolo, note: note, written: duration + duration) {
            context.pendingTremolos[voiceID] = MusicXML.Importer.PendingTremolo(attack: attack,
                                                                                duration: duration,
                                                                                extras: extras,
                                                                                ornamentation: ornamentation,
                                                                                pitch: pitch,
                                                                                strokes: strokes)
            context.lastEvents[voiceID] = (attack, duration)

            return
        }

        if marks.hasCaesura {
            context.addMark(.caesura(nil), at: attack + duration, voiceID: voiceID)
        }

        let tone = Self._insert(pitch,
                                attack: attack,
                                duration: duration,
                                tie: tie,
                                voiceID: voiceID,
                                extras: extras,
                                ornamentation: ornamentation,
                                &context)

        if isChordTone {
            context.lastChords[voiceID]?.tones.append(tone)
        } else {
            context.lastChords[voiceID] = (duration, [tone])
            context.lastEvents[voiceID] = (attack, duration)
        }
    }

    // MARK: Private Type Methods

    // The tone's roll: one group per `<arpeggiate>` number at each attack,
    // shared by every voice of the part. A `<non-arpeggiate>` bracket is
    // dropped, reported once per attack.
    private static func _arpeggio(_ marks: MusicXML.Importer.NoteMarks,
                                  attack: BeatTime,
                                  _ context: inout MusicXML.Importer.Context) -> NoteTable<BeatTime, Pitch>.Arpeggio? {
        if marks.hasNonArpeggiate,
           context.nonArpeggiateAttacks.insert(attack).inserted {
            context.report(.droppedNonArpeggiate)
        }

        guard marks.isArpeggiated
        else { return nil }

        let group: ArpeggioGroup

        if let existing = context.arpeggioGroups[attack]?[marks.arpeggioNumber] {
            group = existing
        } else {
            guard let new = ArpeggioGroup(uintValue: context.nextArpeggioGroup)
            else { return nil }

            group = new
            context.nextArpeggioGroup += 1
            context.arpeggioGroups[attack, default: [:]][marks.arpeggioNumber] = group
        }

        return .init(group: group, direction: marks.arpeggioDirection)
    }

    // Inserts the tone, or holds it while its tie is open (see
    // `MusicXML.Importer.Context.pendingTies`). A tone that ends a tie joins
    // the held one: a tied note is attacked once and released once, so only
    // the first note's `attackVelocity` counts, and only the last note's
    // `releaseVelocity`, and the joined note keeps the ornamentation
    // `NoteTable.Ornamentation.merged(first:last:)` gives. A tone with a
    // figure before it breaks the tie instead: the figure stays before it,
    // and it's attacked again.
    private static func _insert(_ pitch: Pitch,
                                attack: BeatTime,
                                duration: BeatDuration,
                                tie: [MXLTie],
                                voiceID: String?,
                                extras: Extras?,
                                ornamentation: NoteTable<BeatTime, Pitch>.Ornamentation?,
                                _ context: inout MusicXML.Importer.Context) -> MusicXML.Importer.ToneRef {
        let hasStart = tie.contains { $0.kind == .start }
        let hasStop = tie.contains { $0.kind == .stop }

        _ = context.noteTable(forVoice: voiceID)  // registers the voice even when deferred

        if hasStop,
           let pending = context.pendingTies[voiceID]?.removeValue(forKey: pitch) {
            if ornamentation?.graceBefore == nil {
                let joined = MusicXML.Importer.PendingTie(attack: pending.attack,
                                                          duration: pending.duration + duration,
                                                          extras: _joinedExtras(pending.extras, extras),
                                                          ornamentation: .merged(first: pending.ornamentation, last: ornamentation))

                return _place(pitch, joined, isTied: hasStart, voiceID: voiceID, &context)
            }

            _ = _place(pitch, pending, isTied: false, voiceID: voiceID, &context)
        }

        return _place(pitch,
                      MusicXML.Importer.PendingTie(attack: attack, duration: duration, extras: extras, ornamentation: ornamentation),
                      isTied: hasStart,
                      voiceID: voiceID,
                      &context)
    }

    // The extras of two tied notes joined into one: a tied note is attacked
    // once and released once, so only the first note's `attackVelocity`
    // counts, and only the last note's `releaseVelocity`.
    private static func _joinedExtras(_ first: Extras?,
                                      _ last: Extras?) -> Extras? {
        _mergedExtras(first.map { Extras(elements: $0.elements.filter { $0.name != Extra.releaseVelocity.name }) },
                      last.map { Extras(elements: $0.elements.filter { $0.name != Extra.attackVelocity.name }) })
    }

    // The note joining a two-note tremolo's first note and the note that
    // stops it: as long as both, with the second as its partner.
    private static func _joinTwoNoteTremolo(_ pending: MusicXML.Importer.PendingTremolo,
                                            partner: Pitch,
                                            duration: BeatDuration,
                                            voiceID: String?,
                                            _ context: inout MusicXML.Importer.Context) {
        let total = pending.duration + duration
        let old = pending.ornamentation
        let ornamentation = NoteTable<BeatTime, Pitch>.Ornamentation(graceBefore: old?.graceBefore,
                                                                     ornament: .init(sign: .tremolo(.measured(pending.strokes)),
                                                                                     partner: .pitches([partner])),
                                                                     arpeggio: old?.arpeggio,
                                                                     fermata: old?.fermata)
        let noteID = context.noteTables[voiceID, default: NoteTable()].insertImported(attack: pending.attack,
                                                                                      duration: total,
                                                                                      pitch: pending.pitch,
                                                                                      extras: pending.extras,
                                                                                      ornamentation: ornamentation)

        context.pendingTremolos[voiceID] = nil
        context.lastChords[voiceID] = (total, [.inserted(noteID)])
        context.lastEvents[voiceID] = (pending.attack, total)
    }

    // Unions two (optional) extras bags element-wise — used to accumulate
    // articulation/ornament/fingering/slur markers across every leg of a
    // tied note. A mark written on the middle leg of a three-note tie
    // survives to the single `NoteTable` entry the whole tie collapses into,
    // same as one written on the first or last leg.
    private static func _mergedExtras(_ lhs: Extras?, _ rhs: Extras?) -> Extras? {
        switch (lhs, rhs) {
        case (nil, nil):
            nil

        case let (lhs?, nil):
            lhs

        case let (nil, rhs?):
            rhs

        case let (lhs?, rhs?):
            Extras(elements: lhs.elements + rhs.elements)
        }
    }

    // The tone's trill, mordent or tremolo, or else the trill of a wavy line
    // still open in its voice; the wavy lines it starts and stops are opened
    // and closed. A single tremolo's strokes are its marks plus the written
    // note's flags or beams.
    private static func _ornament(_ marks: MusicXML.Importer.NoteMarks,
                                  note: MXLNote,
                                  duration: BeatDuration,
                                  voiceID: String?,
                                  _ context: inout MusicXML.Importer.Context) -> NoteTable<BeatTime, Pitch>.Ornament? {
        var ornament = marks.ornament

        if let tremolo = marks.tremolo {
            switch tremolo.kind {
            case .single:
                ornament = _strokes(tremolo, note: note, written: duration).flatMap {
                    .init(sign: .tremolo(.measured($0)), partner: .repeat)
                }

            case .start,
                 .stop:
                break

            case .unmeasured:
                ornament = .init(sign: .tremolo(.unmeasured), partner: .repeat)
            }
        }

        //
        // A wavy line continues its trill over the notes after it, without the first note's
        // written partner, which belongs to that note's pitch.
        //
        let open = (context.wavyLines[voiceID]?.min { $0.key < $1.key }?.value).flatMap { trill -> NoteTable<BeatTime, Pitch>.Ornament? in
            guard case let .step(side, _) = trill.partner
            else { return trill }

            return .init(sign: trill.sign, partner: .step(side, written: nil), execution: trill.execution)
        }

        for number in marks.wavyLineStarts {
            context.wavyLines[voiceID, default: [:]][number] = marks.ornament
        }

        for number in marks.wavyLineStops {
            context.wavyLines[voiceID]?[number] = nil
        }

        return ornament ?? open
    }

    // Inserts `tie`'s note, or holds it if `isTied`.
    private static func _place(_ pitch: Pitch,
                               _ tie: MusicXML.Importer.PendingTie,
                               isTied: Bool,
                               voiceID: String?,
                               _ context: inout MusicXML.Importer.Context) -> MusicXML.Importer.ToneRef {
        if isTied {
            context.pendingTies[voiceID, default: [:]][pitch] = tie

            return .pending(pitch)
        }

        // Inserts in place: copying the table out and storing it back would copy every
        // note already in it, since the dictionary still holds the original.
        return .inserted(context.noteTables[voiceID, default: NoteTable()].insertImported(attack: tie.attack,
                                                                                          duration: tie.duration,
                                                                                          pitch: pitch,
                                                                                          extras: tie.extras,
                                                                                          ornamentation: tie.ornamentation))
    }

    // A tremolo's strokes: its marks plus the flags or beams of the written
    // note — its `<type>`, or else `written` (resolution 8 of the grace-notes
    // plan).
    private static func _strokes(_ tremolo: MXLTremolo,
                                 note: MXLNote,
                                 written: BeatDuration) -> TremoloStrokes? {
        let flags = note.kind.map { convertToFlagCount(kind: $0.value) } ?? convertToFlagCount(written)

        return TremoloStrokes(uintValue: min(8, max(1, tremolo.value.uintValue + flags)))
    }
}
