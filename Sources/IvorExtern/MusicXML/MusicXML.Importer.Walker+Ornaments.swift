// © 2026 John Gary Pusey (see LICENSE.md)

internal import IvorModel
internal import IvorMXL
internal import IvorTiming
internal import IvorTuning
internal import XestiTools

private import XestiNumbers

// Reading MusicXML's grace notes, ornaments, rolls, fermatas and caesuras:
//
// - Grace notes gather into a run per voice (see `MusicXML.Importer.GraceRun`), a `<chord/>`
//   grace note joining the one before it; the run becomes a figure before the next regular note,
//   or after the one before it.
// - `<trill-mark>`, `<inverted-mordent>` (a partner above) and `<mordent>` (below) take their
//   `trill-sound` as execution and an `<accidental-mark>` as the written partner; a `long`
//   mordent sounds its partner twice. A `<wavy-line>` start puts the trill on every note until
//   its stop. `<tremolo>` is a single, unmeasured or two-note tremolo, its strokes the marks
//   plus the written note's flags or beams (resolution 8 of the grace-notes plan).
// - `<arpeggiate>` rolls a chord: one group per `number` at each attack in the MusicXML part,
//   shared by every voice made from it. `<non-arpeggiate>` is dropped, with a warning.
// - `<fermata>` on a note is its own; on a rest or bar line, a part mark over the rest or the
//   last event before the bar line (resolution 4). `<caesura>` is a part mark at the note's or
//   rest's release.
extension MusicXML.Importer.Walker {

    // MARK: Internal Type Methods

    // Puts `run` after the last regular note or chord of `voiceID`, on its
    // first tone; `false` if the voice has none.
    internal static func attachGraceAfter(_ run: MusicXML.Importer.GraceRun,
                                          voiceID: String?,
                                          _ context: inout MusicXML.Importer.Context) -> Bool {
        guard let last = context.lastChords[voiceID],
              let tone = last.tones.first,
              let figure = run.figure(isAfter: true, mainDuration: last.duration)
        else { return false }

        switch tone {
        case let .inserted(noteID):
            guard let note = context.noteTables[voiceID]?.first(where: { $0.noteID == noteID })
            else { return false }

            let old = note.ornamentation

            _ = try? context.noteTables[voiceID]?.updateOrnamentation(noteID: noteID,
                                                                      ornamentation: .init(graceBefore: old?.graceBefore,
                                                                                           graceAfter: figure,
                                                                                           ornament: old?.ornament,
                                                                                           arpeggio: old?.arpeggio,
                                                                                           fermata: old?.fermata))

        case let .pending(pitch):
            guard var pending = context.pendingTies[voiceID]?[pitch]
            else { return false }

            let old = pending.ornamentation

            pending.ornamentation = .init(graceBefore: old?.graceBefore,
                                          graceAfter: figure,
                                          ornament: old?.ornament,
                                          arpeggio: old?.arpeggio,
                                          fermata: old?.fermata)
            context.pendingTies[voiceID]?[pitch] = pending
        }

        return true
    }

    // A grace run left at the end of a measure follows the note before it
    // in its voice.
    internal static func attachGraceRunsAtMeasureEnd(_ context: inout MusicXML.Importer.Context) {
        for voiceID in Array(context.graceRuns.keys) {
            if let run = context.graceRuns[voiceID],
               attachGraceAfter(run, voiceID: voiceID, &context) {
                context.graceRuns[voiceID] = nil
            }
        }
    }

    // The first note of an open two-note tremolo that no stop came for goes
    // in as a plain note.
    internal static func flushPendingTremolo(voiceID: String?,
                                             _ context: inout MusicXML.Importer.Context) {
        guard let pending = context.pendingTremolos.removeValue(forKey: voiceID)
        else { return }

        let noteID = context.noteTables[voiceID, default: NoteTable()].insertImported(attack: pending.attack,
                                                                                      duration: pending.duration,
                                                                                      pitch: pending.pitch,
                                                                                      extras: pending.extras,
                                                                                      ornamentation: pending.ornamentation)

        context.lastChords[voiceID] = (pending.duration, [.inserted(noteID)])
    }

    // A figure on a chord belongs to its lowest tone: the walk puts it on the
    // first tone written, so it's moved once the voice is read.
    internal static func movingFiguresToLowestTones(_ noteTable: NoteTable<BeatTime, Pitch>) -> NoteTable<BeatTime, Pitch> {
        var table = noteTable
        let chords = Dictionary(grouping: noteTable, by: \.attack)

        for chord in chords.values where chord.count > 1 {
            guard let lowest = chord.min(by: { $0.startPitch < $1.startPitch }),
                  let holder = chord.first(where: { $0.ornamentation?.graceBefore != nil || $0.ornamentation?.graceAfter != nil }),
                  holder.noteID != lowest.noteID
            else { continue }

            let moved = holder.ornamentation
            let kept = lowest.ornamentation

            _ = try? table.updateOrnamentation(noteID: holder.noteID,
                                               ornamentation: nonEmpty(.init(ornament: moved?.ornament,
                                                                             arpeggio: moved?.arpeggio,
                                                                             fermata: moved?.fermata)))
            _ = try? table.updateOrnamentation(noteID: lowest.noteID,
                                               ornamentation: nonEmpty(.init(graceBefore: moved?.graceBefore,
                                                                             graceAfter: moved?.graceAfter,
                                                                             ornament: kept?.ornament,
                                                                             arpeggio: kept?.arpeggio,
                                                                             fermata: kept?.fermata)))
        }

        return table
    }

    internal static func nonEmpty(_ ornamentation: NoteTable<BeatTime, Pitch>.Ornamentation) -> NoteTable<BeatTime, Pitch>.Ornamentation? {
        ornamentation.isEmpty ? nil : ornamentation
    }

    // A `<barline>`'s fermata is a part mark over the last event before it
    // in each voice that reaches it.
    internal static func placeAtBarline(_ barline: MXLBarline,
                                        _ context: inout MusicXML.Importer.Context) {
        guard let fermata = barline.fermata.first
        else { return }

        let offset: MusicXML.Duration = switch barline.location {
        case .left:
            .zero

        case .middle:
            context.cursor

        case .right:
            context.measureAdvance
        }

        let time = convertToBeatTime(context.measureStart + offset)
        let shape = convertToFermataShape(fermata.value)

        for (voiceID, last) in context.lastEvents where last.attack + last.duration == time {
            guard let span = PositiveDuration(last.duration)
            else { continue }

            context.addMark(.fermata(Fermata(shape: shape), span: span), at: last.attack, voiceID: voiceID)
        }
    }

    // What a rest leaves behind: a grace run before it follows the note
    // before it, an open two-note tremolo ends, and a fermata or caesura on
    // the rest becomes a part mark.
    internal static func placeAtRest(_ note: MXLNote,
                                     attack: BeatTime,
                                     duration: BeatDuration,
                                     voiceID: String?,
                                     _ context: inout MusicXML.Importer.Context) {
        if let run = context.graceRuns[voiceID],
           attachGraceAfter(run, voiceID: voiceID, &context) {
            context.graceRuns[voiceID] = nil
        }

        flushPendingTremolo(voiceID: voiceID, &context)

        for item in note.notations.flatMap(\.items) {
            switch item {
            case let .articulations(articulations):
                for case .caesura in articulations.items {
                    context.addMark(.caesura(nil), at: attack + duration, voiceID: voiceID)
                }

            case let .fermata(fermata):
                if let span = PositiveDuration(duration) {
                    context.addMark(.fermata(Fermata(shape: convertToFermataShape(fermata.value)), span: span),
                                    at: attack,
                                    voiceID: voiceID)
                }

            default:
                break
            }
        }

        context.lastEvents[voiceID] = (attack, duration)
    }

    // MARK: Internal Instance Methods

    // What one note's `<notations>` say (see `MusicXML.Importer.NoteMarks`).
    // `written` is the note's written pitch, which a written partner's
    // accidental mark is read against before both are transposed by
    // `transpose`.
    internal func noteMarks(_ note: MXLNote,
                            written: MXLPitch,
                            transpose: MXLTranspose?,
                            _ context: inout MusicXML.Importer.Context) -> MusicXML.Importer.NoteMarks {
        var marks = MusicXML.Importer.NoteMarks()

        for item in note.notations.flatMap(\.items) {
            switch item {
            case let .arpeggiate(arpeggiate):
                marks.isArpeggiated = true
                marks.arpeggioNumber = arpeggiate.number?.uintValue ?? 0
                marks.arpeggioDirection = arpeggiate.direction.map { $0 == .down ? .down : .up }

            case let .articulations(articulations):
                for case .caesura in articulations.items {
                    marks.hasCaesura = true
                }

            case let .fermata(fermata):
                marks.fermata = marks.fermata ?? convertToFermataShape(fermata.value)

            case .nonArpeggiate:
                marks.hasNonArpeggiate = true

            case let .ornaments(ornaments):
                for entry in ornaments.entries {
                    _read(entry, written: written, transpose: transpose, &marks, &context)
                }

            case let .slur(slur) where slur.kind == .stop:
                marks.slurStops.append(slur.number.uintValue)

            default:
                break
            }
        }

        return marks
    }

    // Adds a grace note to its voice's run (see `MusicXML.Importer.GraceRun`).
    // A grace note sets no duration of its own: it neither moves the cursor
    // nor becomes the duration a following `<chord/>` note takes.
    internal func readGraceNote(_ note: MXLNote,
                                fullNote: MXLFullNote,
                                grace: MXLGrace,
                                tie: [MXLTie],
                                measureNumber: String,
                                _ context: inout MusicXML.Importer.Context) throws(MusicXML.Error) {
        let voiceID = note.voice?.voice

        _ = context.noteTable(forVoice: voiceID)  // registers the voice

        guard case let .pitch(written) = fullNote.content
        else { return }

        let sounding = try transposer.transpose(written,
                                                by: Self.activeTranspose(for: note, in: context),
                                                context: "grace note in measure \(measureNumber)")
        let pitch = try convertToStandardPitch(sounding)
        var run = context.graceRuns[voiceID] ?? MusicXML.Importer.GraceRun()

        if fullNote.isChord, !run.events.isEmpty {
            run.events[run.events.count - 1].pitches.append(pitch)
        } else {
            var makeTime: BeatDuration?

            if let divisions = grace.makeTime {
                makeTime = try convertToBeatDuration(rhythm.resolve(count: divisions.intValue,
                                                                    activeDivisions: context.activeDivisions,
                                                                    context: "grace note in measure \(measureNumber)"))
            }

            if run.events.isEmpty {
                run.isSlashed = grace.isSlashed ?? false
            }

            let length = note.kind.flatMap { convertToBeatDuration(kind: $0.value, dots: note.dot.count) }

            run.events.append(MusicXML.Importer.GraceRun.Event(length: length.flatMap(PositiveDuration.init),
                                                               makeTime: makeTime,
                                                               pitches: [pitch],
                                                               stealTimeFollowing: grace.stealTimeFollowing,
                                                               stealTimePrevious: grace.stealTimePrevious))
            run.isTiedForward = tie.contains { $0.kind == .start }
        }

        if grace.stealTimePrevious != nil, grace.stealTimeFollowing == nil, !(grace.isSlashed ?? false) {
            run.followsPrevious = true
        }

        let marks = noteMarks(note, written: written, transpose: nil, &context)

        for number in marks.slurStops {
            Self._unbindSlur(number, voiceID: voiceID, &context)
            run.followsPrevious = true
        }

        for number in marks.wavyLineStops {
            context.wavyLines[voiceID]?[number] = nil
            run.followsPrevious = true
        }

        context.graceRuns[voiceID] = run
    }

    // MARK: Private Type Methods

    // The diatonic neighbor of `pitch` on `side`.
    private static func _neighbor(of pitch: MXLPitch,
                                  side: PartnerSide) -> (step: MXLStep, octave: Int) {
        let steps: [MXLStep] = [.c, .d, .e, .f, .g, .a, .b]
        let index = steps.firstIndex(of: pitch.step) ?? 0
        let octave = Int(pitch.octave.uintValue)

        switch side {
        case .above:
            return index == steps.count - 1 ? (.c, octave + 1) : (steps[index + 1], octave)

        case .below:
            return index == 0 ? (.b, octave - 1) : (steps[index - 1], octave)
        }
    }

    private static func _semitones(_ accidental: Pitch.Accidental) -> Int {
        switch accidental {
        case .doubleFlat:
            -2

        case .doubleSharp:
            2

        case .flat:
            -1

        case .natural:
            0

        case .sharp:
            1
        }
    }

    // A slur that a grace note stops binds a figure to the note before it
    // (see `MusicXML.Exporter.OrnamentWriter`): it's the figure's, so the
    // note's slur start goes.
    private static func _unbindSlur(_ number: UInt,
                                    voiceID: String?,
                                    _ context: inout MusicXML.Importer.Context) {
        guard let tone = context.lastChords[voiceID]?.tones.first
        else { return }

        func unbound(_ extras: Extras?) -> Extras? {
            let kept = extras?.elements.filter {
                !($0.name == Extra.slurStart.name && $0.values == [.string("\(number)")])
            } ?? []

            return kept.isEmpty ? nil : Extras(elements: kept)
        }

        switch tone {
        case let .inserted(noteID):
            guard let note = context.noteTables[voiceID]?.first(where: { $0.noteID == noteID })
            else { return }

            context.noteTables[voiceID]?.updateExtras(noteID: noteID, extras: unbound(note.extras))

        case let .pending(pitch):
            let extras = unbound(context.pendingTies[voiceID]?[pitch]?.extras)

            context.pendingTies[voiceID]?[pitch]?.extras = extras
        }
    }

    // MARK: Private Instance Methods

    // A trill or mordent with its `trill-sound` as execution (resolution 12
    // of the grace-notes plan for `start-note`) and its first accidental mark
    // as the written partner: the diatonic neighbor of the written note on
    // the partner's side, with that accidental, transposed like the note.
    // What the model can't hold — `start-note` on the wrong side, a `unison`
    // step, `accelerate`, `second-beat`, a `two-note-turn` — is dropped with a
    // warning. `beats` counts the notes from the start note, so the partner
    // sounds half of them; `last-beat` is the share of the note the ornament
    // fills, used when `beats` isn't written.
    private func _ornament(sign: NoteTable<BeatTime, Pitch>.Ornament.Sign,
                           side: PartnerSide,
                           trillSound: MXLTrillSound,
                           isLong: Bool,
                           accidentalMarks: [MXLAccidentalMark],
                           written: MXLPitch,
                           transpose: MXLTranspose?,
                           _ context: inout MusicXML.Importer.Context) -> NoteTable<BeatTime, Pitch>.Ornament? {
        var startNote: OrnamentStart?
        var partnerRule: PartnerRule?
        var extent: OrnamentExtent?

        switch (trillSound.startNote, side) {
        case (.main, _):
            startNote = .main

        case (.below, .below),
             (.upper, .above):
            startNote = .partner

        case (nil, _):
            break

        default:
            context.report(.droppedExecution)
        }

        switch trillSound.trillStep {
        case .half:
            partnerRule = .halfStep

        case .unison:
            context.report(.droppedExecution)

        case .whole:
            partnerRule = .wholeStep

        case nil:
            break
        }

        if trillSound.accelerates == true || trillSound.secondBeat != nil
           || (trillSound.twoNoteTurn != nil && trillSound.twoNoteTurn != .omitted) {
            context.report(.droppedExecution)
        }

        if let beats = trillSound.beats {
            let count = Int(beats.rounded(.down))
            let startsOnPartner = (startNote ?? (sign == .trill ? .partner : .main)) == .partner

            extent = AlternationCount(uintValue: UInt(max(1, startsOnPartner ? (count + 1) / 2 : count / 2))).map { .count($0) }
        } else if let lastBeat = trillSound.lastBeat {
            extent = Proportion(numberValue: Number(numerator: Int((lastBeat * 100).rounded()), denominator: 10_000)).map { .span($0) }
        } else if isLong {
            extent = AlternationCount(uintValue: 2).map { .count($0) }
        }

        var writtenPartner: Pitch?

        if let mark = accidentalMarks.first {
            if let accidental = convertToAccidental(mark.value),
               let alter = MusicXML.Semitones(exactly: Self._semitones(accidental)) {
                let neighbor = Self._neighbor(of: written, side: side)

                if let octave = MusicXML.Octave(uintValue: UInt(max(0, neighbor.octave))),
                   let transposed = try? transposer.transpose(MXLPitch(step: neighbor.step,
                                                                       alter: alter == 0 ? nil : alter,
                                                                       octave: octave),
                                                              by: transpose,
                                                              context: "accidental mark") {
                    writtenPartner = try? convertToStandardPitch(transposed)
                }
            } else {
                context.report(.droppedExecution)
            }
        }

        let execution = NoteTable<BeatTime, Pitch>.OrnamentExecution(startNote: startNote,
                                                                     partnerRule: partnerRule,
                                                                     extent: extent)

        return NoteTable<BeatTime, Pitch>.Ornament(sign: sign,
                                                   partner: .step(side, written: writtenPartner),
                                                   execution: execution.isEmpty ? nil : execution)
    }

    private func _read(_ entry: MXLOrnaments.Entry,
                       written: MXLPitch,
                       transpose: MXLTranspose?,
                       _ marks: inout MusicXML.Importer.NoteMarks,
                       _ context: inout MusicXML.Importer.Context) {
        func ornament(_ sign: NoteTable<BeatTime, Pitch>.Ornament.Sign,
                      _ side: PartnerSide,
                      _ trillSound: MXLTrillSound,
                      isLong: Bool = false) -> NoteTable<BeatTime, Pitch>.Ornament? {
            _ornament(sign: sign,
                      side: side,
                      trillSound: trillSound,
                      isLong: isLong,
                      accidentalMarks: entry.accidentalMarks,
                      written: written,
                      transpose: transpose,
                      &context)
        }

        switch entry.content {
        case let .invertedMordent(mordent):
            marks.ornament = ornament(.mordent, .above, mordent.trillSound, isLong: mordent.isLong)

        case let .mordent(mordent):
            marks.ornament = ornament(.mordent, .below, mordent.trillSound, isLong: mordent.isLong)

        case let .tremolo(tremolo):
            marks.tremolo = tremolo

        case let .trillMark(trill):
            marks.ornament = ornament(.trill, .above, trill.trillSound)

        case let .wavyLine(wavyLine):
            let number = wavyLine.number?.uintValue ?? 1

            switch wavyLine.kind {
            case .continue:
                break

            case .start:
                marks.wavyLineStarts.append(number)

                if marks.ornament == nil {
                    marks.ornament = ornament(.trill, .above, wavyLine.trillSound)
                }

            case .stop:
                marks.wavyLineStops.append(number)
            }

        default:
            break
        }
    }
}
