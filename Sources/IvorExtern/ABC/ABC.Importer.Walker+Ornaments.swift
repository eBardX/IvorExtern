// © 2026 John Gary Pusey (see LICENSE.md)

internal import IvorABC
internal import IvorModel
internal import IvorTiming
internal import IvorTuning
internal import XestiNumbers

// Reading ABC's grace groups and ornament decorations into the ornaments staged for the next
// event (see `ABC.Importer.Ornaments`), and placing what a bar line or rest leaves behind.
extension ABC.Importer.Walker {

    // MARK: Internal Type Methods

    internal static func addFermataMark(at attack: BeatTime,
                                        span: BeatDuration,
                                        _ context: inout ABC.Importer.Context) {
        guard let span = PositiveDuration(span)
        else { return }

        context.markTable.insert(time: attack,
                                 mark: .fermata(Fermata(), span: span))
    }

    //
    // What's staged when a bar line comes belongs to the last event before it: a grace group
    // becomes a figure after the pending note (a figure before a bar line is one after the
    // note before it), and a fermata becomes a part mark over the last event (resolution 4 of
    // the grace-notes plan). With no event before them, they wait for the next note.
    //
    internal static func attachToBarLine(_ context: inout ABC.Importer.Context,
                                         rhythm: ABC.Importer.Rhythm) throws(ABC.Error) {
        moveGraceAfterPending(&context)

        guard context.stagedOrnaments.fermata
        else { return }

        if let pending = context.pendingEvent {
            try addFermataMark(at: pending.attack,
                               span: convertToBeatDuration(rhythm.advanceDuration(pending.event)),
                               &context)
        } else if let last = context.lastEvent {
            addFermataMark(at: last.attack, span: last.duration, &context)
        } else {
            return
        }

        context.stagedOrnaments.fermata = false
    }

    //
    // `!tremN!` joins the notes on either side into one note, as long as the two, with the
    // second as its partner (resolution 14 of the grace-notes plan); `nil` unless both are
    // notes.
    //
    internal static func joinedTwoNoteTremolo(_ pending: ABC.Importer.PendingEvent,
                                              _ event: ABC.Event,
                                              marks: UInt,
                                              staged: ABC.Importer.Ornaments) throws(ABC.Error) -> ABC.Importer.PendingEvent? {
        guard case let .note(first) = pending.event,
              case let .note(second) = event
        else { return nil }

        var ornaments = pending.ornaments

        ornaments.absorb(staged)
        ornaments.tremoloMarks = marks
        ornaments.tremoloPartner = try [convertToStandardPitch(second.pitch)]

        return ABC.Importer.PendingEvent(attack: pending.attack,
                                         event: .note(ABC.Note(duration: first.duration + second.duration,
                                                               pitch: first.pitch,
                                                               tie: second.tie)),
                                         extras: pending.extras,
                                         ornaments: ornaments)
    }

    //
    // A staged grace group followed by a rest or a bar line becomes a figure after the pending
    // note or chord, if there is one; otherwise it waits for the next note.
    //
    internal static func moveGraceAfterPending(_ context: inout ABC.Importer.Context) {
        guard let figure = context.stagedOrnaments.graceBefore,
              var pending = context.pendingEvent
        else { return }

        if case .rest = pending.event {
            return
        }

        pending.ornaments.graceAfter = figure
        context.pendingEvent = pending
        context.stagedOrnaments.graceBefore = nil
    }

    //
    // Stages an ornament decoration for the next event: a trill (`!trill!`, `T`, and an extended
    // trill's start, `!trill(!`, whose end mark is dropped since the tied notes it covers merge
    // into one), a mordent with its partner above (`!uppermordent!`, `!pralltriller!`, `P`) or
    // below (`!lowermordent!`, `!mordent!`, `M`), a roll (`!arpeggio!`, with a group of its
    // own), a single tremolo (`!/!`, `!//!`, `!///!`), or a fermata (`!fermata!`, `H`, and
    // `!invertedfermata!`, read as a plain fermata). Returns `false` for any other decoration.
    //
    internal static func stageOrnament(_ name: ABCDecoration.Name,
                                       _ context: inout ABC.Importer.Context) -> Bool {
        switch name.stringValue.lowercased() {
        case "trill",
             "trill(":
            context.stagedOrnaments.ornament = .trill
            context.stagedOrnaments.ornamentSide = .above

        case "trill)":
            break

        case "pralltriller",
             "uppermordent":
            context.stagedOrnaments.ornament = .mordent
            context.stagedOrnaments.ornamentSide = .above

        case "lowermordent",
             "mordent":
            context.stagedOrnaments.ornament = .mordent
            context.stagedOrnaments.ornamentSide = .below

        case "arpeggio":
            context.stagedOrnaments.arpeggio = ArpeggioGroup(uintValue: context.nextArpeggioGroup)
            context.nextArpeggioGroup += 1

        case "/",
             "//",
             "///":
            context.stagedOrnaments.tremoloMarks = UInt(name.stringValue.count)

        case "fermata",
             "invertedfermata":
            context.stagedOrnaments.fermata = true

        default:
            return false
        }

        return true
    }

    // The stroke count of abcm2ps's two-note tremolo marks, `!trem1!` to `!trem4!`.
    internal static func twoNoteTremoloMarks(_ name: ABCDecoration.Name) -> UInt? {
        switch name.stringValue.lowercased() {
        case "trem1":
            1

        case "trem2":
            2

        case "trem3":
            3

        case "trem4":
            4

        default:
            nil
        }
    }

    // MARK: Internal Instance Methods

    //
    // A grace group becomes a figure: one event per note, and one per chord inside the braces,
    // in the renderers' unit — an eighth for a lone grace note, a sixteenth for each of a group,
    // whatever `L:` says — times its written length. A tie from its last note ties it into the
    // main note. Where the figure goes is decided by what follows it (see `_considerTie(_:_:)`
    // and `attachToBarLine(_:rhythm:)`).
    //
    internal func handleGraceNotes(_ graceNotes: ABCGraceNotes,
                                   _ context: inout ABC.Importer.Context) throws(ABC.Error) {
        let unit = Number(numerator: 1, denominator: graceNotes.elements.count == 1 ? 8 : 16)
        var events: [NoteTable<BeatTime, Pitch>.GraceFigure.Event] = []

        for element in graceNotes.elements {
            var pitches: [Pitch] = []

            for note in element.notes {
                let writtenPitch = pitchFolder.resolvedWrittenPitch(note.pitch, &context)

                try pitches.append(convertToStandardPitch(pitchFolder.foldedPitch(writtenPitch, context.activeClef)))
            }

            let written = switch element {
            case let .chord(chord):
                Number(numerator: chord.length.numerator, denominator: chord.length.denominator)
                    * Number(numerator: chord.notes.first?.length.numerator ?? 1, denominator: chord.notes.first?.length.denominator ?? 1)

            case let .note(note):
                Number(numerator: note.length.numerator, denominator: note.length.denominator)
            }

            let length = BeatDuration(numberValue: unit * written).flatMap(PositiveDuration.init)

            if let event = NoteTable<BeatTime, Pitch>.GraceFigure.Event(pitches: Array(Set(pitches)).sorted(),
                                                                        length: length) {
                events.append(event)
            }
        }

        let isTied = switch graceNotes.elements.last {
        case let .chord(chord):
            chord.tie != nil || chord.notes.contains { $0.tie != nil }

        case let .note(note):
            note.tie != nil

        case nil:
            false
        }

        context.stagedOrnaments.graceBefore = NoteTable<BeatTime, Pitch>.GraceFigure(events: events,
                                                                                     isSlashed: graceNotes.isSlashed,
                                                                                     isTiedToMainNote: isTied)
    }
}
