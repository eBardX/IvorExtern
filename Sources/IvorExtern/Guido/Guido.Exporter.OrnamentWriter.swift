// © 2026 John Gary Pusey (see LICENSE.md)

internal import IvorGMN
internal import IvorModel
internal import IvorTiming
internal import IvorTuning
internal import XestiNumbers
internal import XestiTools

extension Guido.Exporter {

    // MARK: Internal Nested Types

    // Writes one part's ornamentation as Guido, the reverse of
    // `Guido.Importer.Walker+Ornaments`: grace figures as `\grace` before
    // their note (a figure after a note goes before the next note, and loses
    // its slash, since Guido has neither), trills and mordents (by their
    // partner's side) with a written partner as `note` and a rate of 1/n
    // notes as `dur`, tremolos with `style` and `speed` (a two-note tremolo
    // with `pitch`, its note at half its length), rolls with their
    // direction, and fermatas with their shape, on notes, on rests and on
    // bar lines (resolution 18 of the grace-notes plan). Caesuras, unsigned
    // ornaments and the executions Guido can't hold are dropped, and
    // reported (see `ExternWarning.Kind`).
    internal struct OrnamentWriter {

        // MARK: Internal Initializers

        internal init(markTable: PartMarkTable<BeatTime>,
                      partIndex: Int,
                      sharedRolls: [RollKey: Int],
                      sliceStarts: Set<BeatTime>,
                      barTimes: Set<BeatTime>,
                      warnings: WarningCollector,
                      workIndex: Int?) {
            self.fermataMarks = FermataMarkPlacements(markTable,
                                                      sliceStarts: sliceStarts,
                                                      barTimes: barTimes) { warnings.add($0, workIndex: workIndex) }
            self.partIndex = partIndex
            self.sharedRolls = sharedRolls
            self.warnings = warnings
            self.workIndex = workIndex
        }

        // MARK: Private Instance Properties

        private let fermataMarks: FermataMarkPlacements
        private let partIndex: Int
        private let sharedRolls: [RollKey: Int]
        private let warnings: WarningCollector
        private let workIndex: Int?

        private var carriedFigure: NoteTable<BeatTime, Pitch>.GraceFigure?
    }
}

// MARK: -

extension Guido.Exporter.OrnamentWriter {

    // MARK: Internal Instance Methods

    // A bar line at `time`, wrapped in `\fermata` if a fermata mark ends
    // there.
    internal func barLineSymbol(_ barLine: GMNBarLine,
                                at time: BeatTime) -> GMNSymbol {
        let symbol = GMNSymbol.tag(.barLine(barLine))

        guard let fermata = fermataMarks.beforeBar[time],
              let tag = Self._fermataTag(fermata, body: [symbol])
        else { return symbol }

        return .tag(tag)
    }

    // A figure after one of the released tones goes before the next note
    // instead: Guido has no figure after a note.
    internal mutating func carryFigureAfter(_ releasedTones: [ExportTone]) {
        guard let figure = releasedTones.lazy.compactMap(\.ornamentation?.graceAfter).first
        else { return }

        carriedFigure = figure
        _report(.movedFigureAfterNote)
    }

    // The `\grace` before the attacked tones: any figure carried from the
    // note before, then the figure on their lowest tone. A grace event
    // with no length is written as an eighth alone, a sixteenth in a group.
    internal mutating func graceSymbols(_ attackedTones: [ExportTone]) throws(Guido.Error) -> [GMNSymbol] {
        let own = attackedTones.min { $0.pitch < $1.pitch }?.ornamentation?.graceBefore
            ?? attackedTones.lazy.compactMap(\.ornamentation?.graceBefore).first
        let carried = carriedFigure
        let events = (carried?.events ?? []) + (own?.events ?? [])

        carriedFigure = nil

        guard !events.isEmpty
        else { return [] }

        if own?.isSlashed ?? false || carried?.isSlashed ?? false {
            _report(.droppedSlash)
        }

        if [carried?.execution, own?.execution].contains(where: { !($0?.isEmpty ?? true) })
           || events.contains(where: { !($0.execution?.isEmpty ?? true) }) {
            _report(.droppedExecution)
        }

        let defaultLength = BeatDuration(numberValue: Number(numerator: 1, denominator: events.count == 1 ? 8 : 16)) ?? .zero
        var body: [GMNSymbol] = []

        for event in events {
            guard let duration = convertToGuidoDuration(event.length?.duration ?? defaultLength)
                  ?? convertToGuidoDuration(defaultLength)
            else { continue }

            var segments: [GMNChord.Segment] = []

            for pitch in event.pitches {
                if let segment = try GMNChord.Segment(symbols: [.note(GMNNote(pitch: convertToGuidoPitch(pitch),
                                                                              duration: duration))]) {
                    segments.append(segment)
                }
            }

            if segments.count == 1, let symbol = segments.first?.symbols.first {
                body.append(symbol)
            } else if let chord = GMNChord(segments: segments) {
                body.append(.chord(chord))
            }
        }

        if own?.isTiedToMainNote ?? false,
           let tie = GMNTie(span: .end) {
            body.append(.tag(.tie(tie)))
        }

        return [.tag(.grace(GMNGrace(body: body)))]
    }

    // The note of a slice holding nothing but one note with a two-note
    // tremolo, written as guidolib writes it: the note at half its length,
    // with the partner as the tremolo's `pitch`; `nil` for anything else,
    // or a half Guido can't write.
    internal func twoNoteTremoloSymbols(_ slice: ExportSlice,
                                        duration: BeatDuration) throws(Guido.Error) -> [GMNSymbol]? {
        guard slice.tones.count == 1,
              let tone = slice.tones.first,
              tone.attack == slice.start,
              !slice.continues(tone),
              let ornament = tone.ornamentation?.ornament,
              case let .tremolo(kind)? = ornament.sign,
              case let .pitches(partners) = ornament.partner,
              let half = duration.divided(by: 2),
              let length = convertToGuidoDuration(half)
        else { return nil }

        let pitchText = partners.map { convertToGuidoPitchText($0, includesOctave: true) }
        let note = try GMNSymbol.note(GMNNote(pitch: convertToGuidoPitch(tone.pitch), duration: length))

        guard let tag = _tremoloTag(kind,
                                    pitch: pitchText.count == 1 ? pitchText[0] : "{" + pitchText.joined(separator: ", ") + "}",
                                    written: half,
                                    execution: ornament.execution,
                                    body: [note])
        else { return nil }

        return [.tag(tag)]
    }

    // The attacked tones' note or chord symbols, wrapped in their ornament
    // (unless `includesOrnament` is false: a two-note tremolo writes its
    // own), their roll, and their fermata, or a fermata mark starting at
    // `start`, innermost first.
    internal func wrapOrnaments(_ symbols: [GMNSymbol],
                                attackedTones: [ExportTone],
                                start: BeatTime,
                                duration: BeatDuration,
                                includesOrnament: Bool) -> [GMNSymbol] {
        var wrapped = symbols

        if includesOrnament,
           let ornament = attackedTones.lazy.compactMap(\.ornamentation?.ornament).first,
           let tag = _ornamentTag(ornament, duration: duration, body: wrapped) {
            wrapped = [.tag(tag)]
        }

        if let tone = attackedTones.first(where: { $0.ornamentation?.arpeggio != nil }),
           let arpeggio = tone.ornamentation?.arpeggio {
            if sharedRolls[RollKey(attack: tone.attack, group: arpeggio.group)] == partIndex {
                _report(.splitArpeggio)
            }

            if !(arpeggio.execution?.isEmpty ?? true) {
                _report(.droppedExecution)
            }

            let direction = arpeggio.direction.map { $0 == .down ? "down" : "up" }

            wrapped = [.tag(.arpeggio(GMNArpeggio(direction: direction, body: wrapped)))]
        }

        if let fermata = attackedTones.lazy.compactMap(\.ornamentation?.fermata).first {
            if fermata.execution != nil {
                _report(.droppedExecution)
            }

            if let tag = Self._fermataTag(fermata, body: wrapped) {
                wrapped = [.tag(tag)]
            }
        } else if let fermata = fermataMarks.atStart[start],
                  let tag = Self._fermataTag(fermata, body: wrapped) {
            wrapped = [.tag(tag)]
        }

        return wrapped
    }

    // A rest's symbols, wrapped in `\fermata` if a fermata mark starts at
    // `start`.
    internal func wrapRest(_ symbols: [GMNSymbol],
                           at start: BeatTime) -> [GMNSymbol] {
        guard let fermata = fermataMarks.atStart[start],
              let tag = Self._fermataTag(fermata, body: symbols)
        else { return symbols }

        return [.tag(tag)]
    }

    // MARK: Private Type Methods

    // A fermata's shape as guidolib's `type`: the very short and very long
    // shapes have none of their own, so they're written as short and long.
    private static func _fermataTag(_ fermata: Fermata<BeatTime>,
                                    body: [GMNSymbol]) -> GMNTag? {
        let type: String? = switch fermata.shape {
        case .long,
             .veryLong:
            "long"

        case .normal:
            nil

        case .short,
             .veryShort:
            "short"
        }

        return GMNArticulation(kind: .fermata, type: type, body: body).map { .articulation($0) }
    }

    // `n` if `duration` is a 1/n note, as `\trill`'s `dur` writes it.
    private static func _reciprocal(_ duration: BeatDuration) -> Int? {
        let value = duration.numberValue

        guard value.isRational,
              value.numerator.intValue == 1
        else { return nil }

        return value.denominator.intValue
    }

    // MARK: Private Instance Methods

    // A trill or mordent tag: a written partner as `note`, a rate of 1/n
    // notes as `dur`, and a mordent's side and number of alternations (one,
    // or two for `prallprall` and `prallinverted`) as `type`.
    private func _ornamentTag(_ ornament: NoteTable<BeatTime, Pitch>.Ornament,
                              duration: BeatDuration,
                              body: [GMNSymbol]) -> GMNTag? {
        switch (ornament.sign, ornament.partner) {
        case (nil, _):
            _report(.droppedOrnament)
            return nil

        case let (.tremolo(kind), .repeat):
            return _tremoloTag(kind, pitch: nil, written: duration, execution: ornament.execution, body: body)

        case (.tremolo, _):
            return nil

        case let (.mordent?, .step(side, written)),
             let (.trill?, .step(side, written)):
            let execution = ornament.execution
            let count: UInt? = if case let .count(count)? = execution?.extent { count.uintValue } else { nil }
            let isDouble = count == 2
            var dur: Int?

            if case let .noteValue(value)? = execution?.rate {
                dur = Self._reciprocal(value.duration)
            }

            //
            // A mordent's type holds one alternation (its default) or two.
            //
            if execution?.startNote != nil || execution?.partnerRule != nil
               || (execution?.rate != nil && dur == nil)
               || (execution?.extent != nil && !(ornament.sign == .mordent && (count == 1 || isDouble))) {
                _report(.droppedExecution)
            }

            let note = written.map { convertToGuidoPitchText($0, includesOctave: false) }

            if ornament.sign == .trill {
                return GMNOrnament(kind: .trill, note: note, dur: dur, body: body).map { .ornament($0) }
            }

            let type: String? = switch (side, isDouble) {
            case (.below, false):
                "inverted"

            case (.below, true):
                "prallinverted"

            case (_, true):
                "prallprall"

            default:
                nil
            }

            return GMNOrnament(kind: .mordent, note: note, type: type, dur: dur, body: body).map { .ornament($0) }

        default:
            return nil
        }
    }

    private func _report(_ kind: ExternWarning.Kind) {
        warnings.add(kind, workIndex: workIndex)
    }

    // A tremolo tag: `speed` is the subdivision its strokes give, and `style`
    // its strokes beyond the `written` note's flags or beams (from one to
    // four). An unmeasured tremolo is written with three strokes and no
    // speed. A rate is dropped.
    private func _tremoloTag(_ kind: NoteTable<BeatTime, Pitch>.Ornament.TremoloKind,
                             pitch: String?,
                             written: BeatDuration,
                             execution: NoteTable<BeatTime, Pitch>.OrnamentExecution?,
                             body: [GMNSymbol]) -> GMNTag? {
        if !(execution?.isEmpty ?? true) {
            _report(.droppedExecution)
        }

        let style: String
        var speed: Int?

        switch kind {
        case let .measured(strokes):
            let marks = min(4, max(1, Int(strokes.uintValue) - Int(convertToFlagCount(written))))

            style = String(repeating: "/", count: marks)
            speed = 1 << (Int(strokes.uintValue) + 2)

        case .unmeasured:
            style = "///"
        }

        return GMNTremolo(style: style, speed: speed, pitch: pitch, body: body).map { .tremolo($0) }
    }
}
