// © 2026 John Gary Pusey (see LICENSE.md)

internal import Foundation
internal import IvorGMN
internal import IvorModel
internal import IvorTiming
internal import IvorTuning
internal import XestiNumbers

// Reading Guido's grace notes and ornament tags into the ornaments of the next note or chord
// (see `Guido.Importer.Ornaments`), and placing what a rest or bar line leaves behind:
//
// - `\grace` is a figure before the next note: one event per note or chord in its body, each
//   with its written duration as its length. A `\grace` inside it is flattened into it and its
//   `i` is ignored, as guidolib does; grace rests are dropped. A `\tieEnd` after its last note
//   ties it into the main note. A figure before a rest follows the note before the rest instead.
// - `\trill` and `\mordent` (`type="prall"`, the default, has its partner above;
//   `type="inverted"` below; `prallprall` and `prallinverted` sound their partner twice): `note`
//   is the written partner, adjusted by a whole number of half steps in `detune`, and `dur` the
//   rate (a sequence of 1/`dur` notes). guidolib's `begin` needs nothing: every note of a
//   trill's range gets the trill.
// - `\tremolo`: `speed` is the subdivision, else `style` gives the strokes beyond the written
//   note's flags or beams (resolution 8 of the grace-notes plan). With `pitch`, it's a two-note
//   tremolo: as in guidolib, the note is written at half the length of the whole tremolo.
// - `\arpeggio` rolls each chord in it, with a group of its own, and its `direction`.
// - `\fermata` with `type` (`short`, `regular`, `long`) on a note is the note's own; on a rest,
//   a part mark over the rest; on a bar line, or bodiless between notes, a part mark over the
//   last event before it (resolution 4).
extension Guido.Importer.Walker {

    // MARK: Internal Type Methods

    // Ends the span a `\trillEnd` or `\tremoloEnd` closes: the latest one
    // of its kind (and ident, if it has one) still open.
    internal static func closeOrnamentSpan(_ tag: GMNTag,
                                           _ context: inout Guido.Importer.Context) {
        guard let index = context.activeOrnamentTags.lastIndex(where: { _closes(tag, $0) })
        else { return }

        context.activeOrnamentTags.remove(at: index)
    }

    // A grace figure read before a rest, or at the end of the voice,
    // follows the pending note instead, if it has none yet; otherwise it
    // waits for the next note.
    internal static func moveGraceAfterPending(_ context: inout Guido.Importer.Context) {
        guard let figure = context.stagedGrace,
              var pending = context.pendingNote,
              pending.ornaments.graceAfter == nil
        else { return }

        pending.ornaments.graceAfter = figure
        context.pendingNote = pending
        context.stagedGrace = nil
    }

    // A fermata on a bar line (`\fermata(\bar)`), or a bodiless one waiting
    // for the next note, is a part mark over the last event before the bar
    // line. Every other bodiless ornament tag waiting for the next note is
    // dropped; with no event before it, a fermata keeps waiting.
    internal static func placeAtBarLine(_ context: inout Guido.Importer.Context) {
        let shape = _fermataShape(in: context.activeOrnamentTags + context.stagedOrnamentTags)

        if let shape,
           let last = context.lastEvent {
            context.addFermataMark(at: last.attack, span: last.duration, shape: shape)
            context.stagedOrnamentTags = []
        } else {
            context.stagedOrnamentTags.removeAll { !_isFermata($0) }
        }
    }

    // What a rest of `duration` at the current time leaves behind: a grace
    // figure before it follows the pending note, a fermata on it is a part
    // mark over it, and every other ornament tag waiting for the next note
    // is dropped.
    internal static func placeBeforeRest(duration: BeatDuration,
                                         _ context: inout Guido.Importer.Context) {
        moveGraceAfterPending(&context)

        if let shape = _fermataShape(in: context.activeOrnamentTags + context.stagedOrnamentTags) {
            context.addFermataMark(at: context.currentBeatTime, span: duration, shape: shape)
        }

        context.stagedOrnamentTags = []
    }

    // A bodiless `\fermata` between notes is a part mark over the last
    // event before it; with none, it waits for the next note.
    internal static func placeBodilessFermata(_ fermata: GMNArticulation,
                                              _ context: inout Guido.Importer.Context) {
        guard let last = context.lastEvent
        else {
            context.stagedOrnamentTags.append(.articulation(fermata))
            return
        }

        context.addFermataMark(at: last.attack,
                               span: last.duration,
                               shape: _fermataShape(fermata.type))
    }

    // The ornaments of the note or chord just read, `notes`, from the grace
    // figure and ornament tags in force, which this uses up. A two-note
    // tremolo doubles each note's duration, since its note is written at
    // half the length of the whole tremolo.
    internal static func takeOrnaments(_ notes: inout [Guido.Note],
                                       _ context: inout Guido.Importer.Context) -> Guido.Importer.Ornaments {
        var ornaments = Guido.Importer.Ornaments()

        ornaments.graceBefore = context.stagedGrace

        for tag in context.activeOrnamentTags + context.stagedOrnamentTags {
            _apply(tag, &ornaments, &notes, &context)
        }

        context.stagedGrace = nil
        context.stagedOrnamentTags = []

        return ornaments
    }

    // MARK: Internal Instance Methods

    // Reads a `\grace` body into the figure before the next note, after any
    // figure already waiting for it.
    internal func stageGrace(_ grace: GMNGrace,
                             _ context: inout Guido.Importer.Context,
                             _ inProgressVariableNames: inout Set<GMNVariable.Name>) throws(Guido.Error) {
        var events = context.stagedGrace?.events ?? []
        var isTied = false

        try _collectGraceEvents(grace.body, &events, &isTied, &context, &inProgressVariableNames)

        context.stagedGrace = NoteTable<BeatTime, Pitch>.GraceFigure(events: events,
                                                                     isTiedToMainNote: isTied)
    }

    // MARK: Private Type Properties

    private static let accidentalSteps: [Pitch.Accidental] = [.doubleFlat, .flat, .natural, .sharp, .doubleSharp]

    // MARK: Private Type Methods

    private static func _apply(_ tag: GMNTag,
                               _ ornaments: inout Guido.Importer.Ornaments,
                               _ notes: inout [Guido.Note],
                               _ context: inout Guido.Importer.Context) {
        switch tag {
        case let .arpeggio(arpeggio):
            ornaments.isArpeggiated = true
            ornaments.arpeggioDirection = switch arpeggio.direction?.lowercased() {
            case "down":
                .down

            case "up":
                .up

            default:
                nil
            }

        case let .articulation(articulation) where articulation.kind == .fermata:
            ornaments.fermata = _fermataShape(articulation.type)

        case let .ornament(ornament):
            _applyOrnament(ornament, &ornaments, &context)

        case let .tremolo(tremolo):
            _applyTremolo(tremolo, &ornaments, &notes)

        default:
            break
        }
    }

    private static func _applyOrnament(_ ornament: GMNOrnament,
                                       _ ornaments: inout Guido.Importer.Ornaments,
                                       _ context: inout Guido.Importer.Context) {
        var extent: OrnamentExtent?

        switch (ornament.kind, ornament.type?.lowercased()) {
        case (.trill, _):
            ornaments.ornamentSign = .trill
            ornaments.ornamentSide = .above

        case (.mordent, "inverted"):
            ornaments.ornamentSign = .mordent
            ornaments.ornamentSide = .below

        case (.mordent, "prallinverted"):
            ornaments.ornamentSign = .mordent
            ornaments.ornamentSide = .below
            extent = AlternationCount(uintValue: 2).map { .count($0) }

        case (.mordent, "prallprall"):
            ornaments.ornamentSign = .mordent
            ornaments.ornamentSide = .above
            extent = AlternationCount(uintValue: 2).map { .count($0) }

        case (.mordent, _):
            ornaments.ornamentSign = .mordent
            ornaments.ornamentSide = .above

        case (.turn, _):
            return
        }

        let rate = ornament.dur.flatMap(_rate)

        ornaments.ornamentExecution = rate == nil && extent == nil ? nil : .init(rate: rate, extent: extent)
        ornaments.tremoloPartner = nil
        ornaments.writtenPartner = _writtenPartner(ornament, &context)
    }

    // A tremolo applies to the note or chord's first tone's written length;
    // a two-note tremolo's partner takes the octave of that tone unless its
    // `pitch` says otherwise, as in guidolib.
    private static func _applyTremolo(_ tremolo: GMNTremolo,
                                      _ ornaments: inout Guido.Importer.Ornaments,
                                      _ notes: inout [Guido.Note]) {
        guard let first = notes.first,
              let strokes = _tremoloStrokes(tremolo, written: convertToBeatDuration(first.duration))
        else { return }

        let wasTwoNote = ornaments.tremoloPartner != nil
        let partner = tremolo.pitch.map { _parsePitches($0, defaultOctave: first.pitch.octave) } ?? []
        let pitches = Array(Set(partner.compactMap { try? convertToStandardPitch($0) })).sorted()

        ornaments.ornamentSign = .tremolo(.measured(strokes))
        ornaments.ornamentExecution = nil
        ornaments.tremoloPartner = pitches.isEmpty ? nil : pitches
        ornaments.writtenPartner = nil

        if !pitches.isEmpty, !wasTwoNote {
            notes = notes.map {
                Guido.Note(duration: Guido.Duration(numberValue: $0.duration.numberValue * 2),
                           pitch: $0.pitch)
            }
        }
    }

    // Whether the `\trillEnd` or `\tremoloEnd` in `endTag` closes the span
    // `openTag` opened.
    private static func _closes(_ endTag: GMNTag,
                                _ openTag: GMNTag) -> Bool {
        switch (endTag, openTag) {
        case let (.ornament(end), .ornament(open)):
            end.kind == open.kind && (end.ident == nil || end.ident == open.ident)

        case let (.tremolo(end), .tremolo(open)):
            end.ident == nil || end.ident == open.ident

        default:
            false
        }
    }

    private static func _fermataShape(_ type: String?) -> FermataShape {
        switch type?.lowercased() {
        case "long":
            .long

        case "short":
            .short

        default:
            .normal
        }
    }

    // The shape of the last fermata among `tags`, if there is one.
    private static func _fermataShape(in tags: [GMNTag]) -> FermataShape? {
        for tag in tags.reversed() {
            if case let .articulation(articulation) = tag,
               articulation.kind == .fermata {
                return _fermataShape(articulation.type)
            }
        }

        return nil
    }

    private static func _isFermata(_ tag: GMNTag) -> Bool {
        if case let .articulation(articulation) = tag {
            return articulation.kind == .fermata
        }

        return false
    }

    // The pitches of a note or chord written as a parameter (`"g"`,
    // `"{c2, e}"`), each taking the octave before it, or `defaultOctave`.
    private static func _parsePitches(_ text: String,
                                      defaultOctave: GMNPitch.Octave) -> [Guido.Pitch] {
        guard let (score, _) = try? Guido.BaseParser().parse(Data("[ \(text) ]".utf8)),
              let symbol = score.voices.first?.symbols.first
        else { return [] }

        let gmnPitches: [GMNPitch] = switch symbol {
        case let .chord(chord):
            chord.segments.flatMap { segment in
                segment.symbols.compactMap { symbol -> GMNPitch? in
                    guard case let .note(note) = symbol
                    else { return nil }

                    return note.pitch
                }
            }

        case let .note(note):
            [note.pitch]

        default:
            []
        }

        var octave = defaultOctave
        var pitches: [Guido.Pitch] = []

        for gmnPitch in gmnPitches {
            octave = gmnPitch.octave ?? octave

            let pitch = Guido.Pitch(accidental: resolvedAccidental(gmnPitch.accidental),
                                    name: resolvedName(gmnPitch.name),
                                    octave: octave)

            if pitch.name != .empty {
                pitches.append(pitch)
            }
        }

        return pitches
    }

    private static func _rate(_ dur: Int) -> NoteTable<BeatTime, Pitch>.OrnamentExecution.Rate? {
        guard dur > 0
        else { return nil }

        return BeatDuration(numberValue: Number(numerator: 1, denominator: dur))
            .flatMap(PositiveDuration.init)
            .map { .noteValue($0) }
    }

    private static func _tremoloStrokes(_ tremolo: GMNTremolo,
                                        written: BeatDuration) -> TremoloStrokes? {
        let strokes: Int

        if let speed = tremolo.speed,
           speed >= 8,
           speed.nonzeroBitCount == 1 {
            strokes = speed.trailingZeroBitCount - 2
        } else {
            let marks = tremolo.style.map { $0.count { $0 == "/" } } ?? 0

            strokes = (marks > 0 ? marks : 3) + Int(convertToFlagCount(written))
        }

        return TremoloStrokes(uintValue: UInt(min(8, max(1, strokes))))
    }

    // The pitch class of a `\trill` or `\mordent`'s `note`, its accidental
    // moved by `detune` half steps. A detune that isn't a whole number of
    // half steps, or moves the accidental past a double sharp or flat, drops
    // the written partner (reported as a dropped execution).
    private static func _writtenPartner(_ ornament: GMNOrnament,
                                        _ context: inout Guido.Importer.Context) -> PitchClass? {
        guard let text = ornament.note,
              let gPitch = _parsePitches(text, defaultOctave: context.lastOctave).first,
              let pitchClass = try? convertToStandardPitch(gPitch).pitchClass
        else { return nil }

        guard let detune = ornament.detune,
              detune != 0
        else { return pitchClass }

        guard detune.rounded() == detune,
              let index = accidentalSteps.firstIndex(of: pitchClass.accidental),
              accidentalSteps.indices.contains(index + Int(detune))
        else {
            context.warningCounts[.droppedExecution, default: 0] += 1
            return nil
        }

        return PitchClass(letter: pitchClass.letter,
                          accidental: accidentalSteps[index + Int(detune)])
    }

    // MARK: Private Instance Methods

    // Each note or chord of a `\grace` body, as one event, resolving its
    // duration and octave like any other note's.
    private func _collectGraceEvents(_ symbols: [GMNSymbol],
                                     _ events: inout [NoteTable<BeatTime, Pitch>.GraceFigure.Event],
                                     _ isTied: inout Bool,
                                     _ context: inout Guido.Importer.Context,
                                     _ inProgressVariableNames: inout Set<GMNVariable.Name>) throws(Guido.Error) {
        for symbol in symbols {
            switch symbol {
            case let .chord(chord):
                let members = try Self.resolveChordMembers(chord, &context).filter { $0.note.pitch.name != .empty }
                var pitches: [Pitch] = []

                for member in members {
                    try pitches.append(convertToStandardPitch(member.note.pitch))
                }

                let length = members.map { convertToBeatDuration($0.note.duration) }.max().flatMap(PositiveDuration.init)

                if let event = NoteTable<BeatTime, Pitch>.GraceFigure.Event(pitches: Array(Set(pitches)).sorted(),
                                                                            length: length) {
                    events.append(event)
                    isTied = members.contains(where: \.isTied)
                }

            case let .note(note):
                let resolved = try Self.resolveNote(note, &context)

                guard resolved.pitch.name != .empty
                else { continue }

                if let event = try NoteTable<BeatTime, Pitch>.GraceFigure.Event(pitches: [convertToStandardPitch(resolved.pitch)],
                                                                                length: PositiveDuration(convertToBeatDuration(resolved.duration))) {
                    events.append(event)
                    isTied = false
                }

            case let .rest(rest):
                _ = try Self.resolveRestDuration(rest, &context)

            case .tablature:
                throw Guido.Error.unsupportedEvent(symbol)

            case let .tag(.tie(tie)):
                if !events.isEmpty, tie.span != .whole {
                    isTied = true
                }

            case let .tag(tag):
                try _collectGraceEvents(tag.body, &events, &isTied, &context, &inProgressVariableNames)

            case let .variable(name):
                guard !inProgressVariableNames.contains(name)
                else { throw Guido.Error.circularVariableReference(name) }

                inProgressVariableNames.insert(name)

                defer { inProgressVariableNames.remove(name) }

                try _collectGraceEvents(expandedSymbols(name), &events, &isTied, &context, &inProgressVariableNames)
            }
        }
    }
}
