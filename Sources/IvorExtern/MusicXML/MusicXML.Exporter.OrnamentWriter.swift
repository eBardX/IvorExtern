// © 2026 John Gary Pusey (see LICENSE.md)

internal import IvorModel
internal import IvorMXL
internal import IvorTiming
internal import IvorTuning
internal import XestiNumbers
internal import XestiTools

extension MusicXML.Exporter {

    // MARK: Internal Nested Types

    // Writes one part's ornamentation as MusicXML, the reverse of
    // `MusicXML.Importer.Walker+Ornaments`: grace figures as grace notes
    // before and after their notes, in document order, with their slash and
    // their timing as `steal-time-previous` and `steal-time-following`; a
    // figure after a note is bound to it by a slur from the note to its last
    // grace note, so it reads back as a figure after (MuseScore's rule);
    // trills and mordents with their `trill-sound`, their written partner as
    // an `<accidental-mark>`, and a `<wavy-line>` over a trill that's split
    // into tied pieces; tremolos (a two-note tremolo split back into two
    // halves with a 2:1 `<time-modification>`); `<arpeggiate>`, numbered
    // only when one attack has several rolls; fermatas on notes, rests and
    // bar lines; and caesuras at the release of the note or rest they
    // follow. What MusicXML can't hold is dropped and reported (see
    // `ExternWarning.Kind`).
    internal struct OrnamentWriter {

        // MARK: Internal Initializers

        internal init(part: Part<BeatTime, Pitch>,
                      partIndex: Int,
                      sharedRolls: [RollKey: Int],
                      sliceStarts: Set<BeatTime>,
                      barTimes: Set<BeatTime>,
                      warnings: WarningCollector,
                      workIndex: Int?) {
            var rollsByAttack: [BeatTime: Set<ArpeggioGroup>] = [:]
            var slurNumbers: [UInt] = [0]

            for note in part.noteTable {
                if let group = note.ornamentation?.arpeggio?.group {
                    rollsByAttack[note.attack, default: []].insert(group)
                }

                for element in note.extras?.elements ?? [] where element.name == Extra.slurStart.name {
                    if case let .string(text)? = element.values.first, let number = UInt(text) {
                        slurNumbers.append(number)
                    }
                }
            }

            self.bindingSlur = MXLNumberLevel(uintValue: min(16, (slurNumbers.max() ?? 0) + 1))
            self.fermataMarks = FermataMarkPlacements(part.markTable,
                                                      sliceStarts: sliceStarts,
                                                      barTimes: barTimes,
                                                      keepsCaesuras: true) { warnings.add($0, workIndex: workIndex) }
            self.partIndex = partIndex
            self.rollsByAttack = rollsByAttack.mapValues { $0.sorted { $0.uintValue < $1.uintValue } }
            self.sharedRolls = sharedRolls
            self.warnings = warnings
            self.workIndex = workIndex
        }

        // MARK: Private Instance Properties

        private let bindingSlur: MXLNumberLevel?
        private let fermataMarks: FermataMarkPlacements
        private let partIndex: Int
        private let rollsByAttack: [BeatTime: [ArpeggioGroup]]
        private let sharedRolls: [RollKey: Int]
        private let warnings: WarningCollector
        private let workIndex: Int?
    }
}

// MARK: -

extension MusicXML.Exporter.OrnamentWriter {

    // MARK: Internal Instance Methods

    // A `<barline>` holding the fermata mark that ends at `time`, if any.
    internal func barlineItem(at time: BeatTime) -> MXLMusicItem? {
        guard let fermata = fermataMarks.beforeBar[time]
        else { return nil }

        return .barline(MXLBarline(fermata: [MXLFermata(value: convertToMusicXMLFermataShape(fermata.shape))]))
    }

    // The grace notes of the figure after the released tones' lowest tone,
    // the last one stopping the slur that binds the figure to it.
    internal func graceAfterItems(_ releasedTones: [ExportTone]) throws(MusicXML.Error) -> [MXLMusicItem] {
        guard let tone = _figureHolder(releasedTones, \.graceAfter),
              let figure = tone.ornamentation?.graceAfter
        else { return [] }

        return try _graceItems(figure, isAfter: true, mainDuration: tone.duration, tiedPitches: [])
    }

    // The grace notes of the figure before the attacked tones' lowest tone.
    // A tie from its last grace note goes to a main tone of the same pitch
    // (see `isTiedFromFigure(_:in:)`).
    internal func graceBeforeItems(_ attackedTones: [ExportTone]) throws(MusicXML.Error) -> [MXLMusicItem] {
        guard let tone = _figureHolder(attackedTones, \.graceBefore),
              let figure = tone.ornamentation?.graceBefore
        else { return [] }

        let tiedPitches = figure.isTiedToMainNote ? Set(attackedTones.map(\.pitch)) : []

        return try _graceItems(figure, isAfter: false, mainDuration: tone.duration, tiedPitches: tiedPitches)
    }

    // Whether `tone` is the main note a figure before it is tied into.
    internal func isTiedFromFigure(_ tone: ExportTone,
                                   in attackedTones: [ExportTone]) -> Bool {
        guard let figure = _figureHolder(attackedTones, \.graceBefore)?.ornamentation?.graceBefore,
              figure.isTiedToMainNote
        else { return false }

        return figure.events.last?.pitches.contains(tone.pitch) ?? false
    }

    // The ornamentation items of one tone in `slice`: on its attacked piece,
    // its ornament, roll and fermata (or a fermata mark starting there); a
    // trill's wavy line from its first piece to its last; on its released
    // piece, a caesura after it, and the start of the slur that binds a
    // figure after it.
    internal func notationItems(for tone: ExportTone,
                                in slice: ExportSlice,
                                duration: BeatDuration,
                                includesOrnament: Bool) -> [MXLNotations.Item] {
        var items: [MXLNotations.Item] = []
        let isAttacked = !slice.isTiedIn(tone)
        let isReleased = !slice.continues(tone)
        let ornament = tone.ornamentation?.ornament

        if isAttacked {
            if includesOrnament, let ornament {
                items += _ornamentItems(ornament, tone: tone, duration: duration)
            }

            items += _arpeggioItems(tone, in: slice)

            if let fermata = tone.ornamentation?.fermata {
                if fermata.execution != nil {
                    _report(.droppedExecution)
                }

                items.append(.fermata(MXLFermata(value: convertToMusicXMLFermataShape(fermata.shape))))
            } else if let fermata = fermataMarks.atStart[slice.start] {
                items.append(.fermata(MXLFermata(value: convertToMusicXMLFermataShape(fermata.shape))))
            }
        }

        if ornament?.sign == .trill, isAttacked != isReleased {
            items.append(.ornaments(MXLOrnaments(entries: [.init(content: .wavyLine(MXLWavyLine(kind: isAttacked ? .start : .stop)))])))
        }

        if isReleased {
            if fermataMarks.caesuras.contains(slice.end) {
                items.append(.articulations(MXLArticulations(items: [.caesura(MXLCaesura(value: .normal))])))
            }

            if tone.ornamentation?.graceAfter != nil,
               tone.index == _figureHolder([tone], \.graceAfter)?.index,
               let bindingSlur {
                items.append(.slur(MXLSlur(kind: .start, number: bindingSlur)))
            }
        }

        return items
    }

    // A rest's notations: a fermata mark starting at it, and a caesura at
    // its end.
    internal func restNotations(_ slice: ExportSlice) -> [MXLNotations] {
        var items: [MXLNotations.Item] = []

        if let fermata = fermataMarks.atStart[slice.start] {
            items.append(.fermata(MXLFermata(value: convertToMusicXMLFermataShape(fermata.shape))))
        }

        if fermataMarks.caesuras.contains(slice.end) {
            items.append(.articulations(MXLArticulations(items: [.caesura(MXLCaesura(value: .normal))])))
        }

        return items.isEmpty ? [] : [MXLNotations(items: items)]
    }

    // A slice holding nothing but one note with a two-note tremolo, written
    // as MusicXML writes it: two notes of half its length with a 2:1
    // `<time-modification>`, the note and its partner (a chord, if it has
    // several), the first starting the tremolo and the second stopping it;
    // `nil` for anything else, or halves the divisions can't hold. The first
    // half carries the note's marks, the second its slur end.
    internal func twoNoteTremoloItems(_ slice: ExportSlice,
                                      duration: BeatDuration,
                                      divisions: Int) throws(MusicXML.Error) -> [MXLMusicItem]? {
        guard slice.tones.count == 1,
              let tone = slice.tones.first,
              tone.attack == slice.start,
              !slice.continues(tone),
              let ornament = tone.ornamentation?.ornament,
              case let .tremolo(kind)? = ornament.sign,
              case let .pitches(partners) = ornament.partner,
              let half = duration.divided(by: 2),
              let halfDivisions = convertToMusicXMLDivisions(half, divisions),
              Number(halfDivisions.intValue) == half.numberValue * 4 * Number(divisions)
        else { return nil }

        if !(ornament.execution?.isEmpty ?? true) {
            _report(.droppedExecution)
        }

        let notationItems = convertToMusicXMLNotationItems(tone.extras?.elements ?? [])
            + convertToMusicXMLSlurStartItems(tone.extras?.elements ?? [])
            + notationItems(for: tone, in: slice, duration: duration, includesOrnament: false)
        let marks: UInt = switch kind {
        case let .measured(strokes):
            UInt(min(8, max(0, Int(strokes.uintValue) - Int(convertToFlagCount(duration)))))

        case .unmeasured:
            3
        }

        let type = convertToMusicXMLNoteKind(duration).map { MXLNote.Kind(value: $0.kind) }
        let dots = Array(repeating: MXLEmptyPlacement(printStyle: MXLPrintStyle()),
                         count: convertToMusicXMLNoteKind(duration)?.dots ?? 0)
        let timeModification = MXLTimeModification(actualNotes: 2, normalNotes: 1)

        func tremolo(_ tremoloKind: MXLTremolo.Kind) -> MXLNotations.Item {
            .ornaments(MXLOrnaments(entries: [.init(content: .tremolo(MXLTremolo(value: MXLTremoloMarks(uintValue: marks).require(),
                                                                                 kind: tremoloKind)))]))
        }

        let stopItems = [tremolo(.stop)] + convertToMusicXMLSlurEndItems(tone.extras?.elements ?? [])
        var items: [MXLMusicItem] = []

        try items.append(.note(MXLNote(content: .regularNote(fullNote: MXLFullNote(isChord: false,
                                                                                   content: .pitch(convertToMusicXMLPitch(tone.pitch))),
                                                             duration: halfDivisions,
                                                             tie: []),
                                       kind: type,
                                       dot: dots,
                                       timeModification: timeModification,
                                       notations: [MXLNotations(items: notationItems + [tremolo(.start)])])))

        for (index, partner) in partners.enumerated() {
            try items.append(.note(MXLNote(content: .regularNote(fullNote: MXLFullNote(isChord: index > 0,
                                                                                       content: .pitch(convertToMusicXMLPitch(partner))),
                                                                 duration: halfDivisions,
                                                                 tie: []),
                                           kind: type,
                                           dot: dots,
                                           timeModification: timeModification,
                                           notations: index == 0 ? [MXLNotations(items: stopItems)] : [])))
        }

        return items
    }

    // MARK: Private Type Methods

    // The tone holding a figure among `tones`: the lowest one with one in
    // `slot`.
    private static func _holder(_ tones: [ExportTone],
                                _ slot: KeyPath<NoteTable<BeatTime, Pitch>.Ornamentation, NoteTable<BeatTime, Pitch>.GraceFigure?>) -> ExportTone? {
        tones.filter { $0.ornamentation?[keyPath: slot] != nil }.min { ($0.pitch, $0.index) < ($1.pitch, $1.index) }
    }

    // The diatonic neighbor letter of `letter` on `side`.
    private static func _neighbor(of letter: Pitch.Letter,
                                  side: PartnerSide) -> Pitch.Letter {
        let letters: [Pitch.Letter] = [.c, .d, .e, .f, .g, .a, .b]
        let index = letters.firstIndex(of: letter) ?? 0

        return letters[(index + (side == .above ? 1 : letters.count - 1)) % letters.count]
    }

    private static func _percent(_ amount: NoteTable<BeatTime, Pitch>.Amount?) -> MXLPercent? {
        guard case let .share(proportion)? = amount
        else { return nil }

        return proportion.numberValue.doubleValue * 100
    }

    // MARK: Private Instance Methods

    // `<arpeggiate>` on a tone of a roll, numbered when its attack has
    // several. A roll's warnings are reported once, by its first tone.
    private func _arpeggioItems(_ tone: ExportTone,
                                in slice: ExportSlice) -> [MXLNotations.Item] {
        guard let arpeggio = tone.ornamentation?.arpeggio
        else { return [] }

        let isFirst = slice.attackedTones.first { $0.ornamentation?.arpeggio?.group == arpeggio.group }?.index == tone.index

        if isFirst, sharedRolls[RollKey(attack: tone.attack, group: arpeggio.group)] == partIndex {
            _report(.splitArpeggio)
        }

        if isFirst, !(arpeggio.execution?.isEmpty ?? true) {
            _report(.droppedExecution)
        }

        let groups = rollsByAttack[tone.attack] ?? []
        let number = groups.count > 1 ? groups.firstIndex(of: arpeggio.group).flatMap { MXLNumberLevel(uintValue: UInt($0 + 1)) } : nil

        return [.arpeggiate(MXLArpeggiate(number: number,
                                          direction: arpeggio.direction.map { $0 == .down ? .down : .up }))]
    }

    private func _figureHolder(_ tones: [ExportTone],
                               _ slot: KeyPath<NoteTable<BeatTime, Pitch>.Ornamentation, NoteTable<BeatTime, Pitch>.GraceFigure?>) -> ExportTone? {
        Self._holder(tones, slot)
    }

    // One figure's grace notes. Each event's timing is its own, else the
    // figure's: time from the main note is `steal-time-following` before it
    // and `steal-time-previous` after it, and time from the other neighbor
    // the other way round. Lengths are written as note types, an event
    // with none (or one no type writes) as an eighth alone, a sixteenth in a
    // group.
    private func _graceItems(_ figure: NoteTable<BeatTime, Pitch>.GraceFigure,
                             isAfter: Bool,
                             mainDuration: BeatDuration,
                             tiedPitches: Set<Pitch>) throws(MusicXML.Error) -> [MXLMusicItem] {
        let defaultKind: MXLNoteKindValue = figure.events.count == 1 ? .eighth : .n16th
        var items: [MXLMusicItem] = []

        for (eventIndex, event) in figure.events.enumerated() {
            let execution = event.execution ?? figure.execution
            let fromMain = execution?.fromMain
            let fromNeighbor = execution?.fromPrevious
            let isLast = eventIndex == figure.events.count - 1

            if [fromMain, fromNeighbor].contains(where: { if case .duration? = $0 { true } else { false } }) {
                _report(.droppedExecution)
            }

            let grace = MXLGrace(stealTimePrevious: Self._percent(isAfter ? fromMain : fromNeighbor),
                                 stealTimeFollowing: Self._percent(isAfter ? fromNeighbor : fromMain),
                                 isSlashed: figure.isSlashed ? true : nil)
            let written = event.length.flatMap { convertToMusicXMLNoteKind($0.duration) } ?? (defaultKind, 0)

            for (pitchIndex, pitch) in event.pitches.enumerated() {
                let isTied = isLast && tiedPitches.contains(pitch)
                var notationItems: [MXLNotations.Item] = isTied ? [.tied(MXLTied(kind: .start))] : []

                if isAfter, isLast, pitchIndex == 0, let bindingSlur {
                    notationItems.append(.slur(MXLSlur(kind: .stop, number: bindingSlur)))
                }

                try items.append(.note(MXLNote(content: .graceNote(fullNote: MXLFullNote(isChord: pitchIndex > 0,
                                                                                         content: .pitch(convertToMusicXMLPitch(pitch))),
                                                                   grace: grace,
                                                                   tie: isTied ? [MXLTie(kind: .start)] : []),
                                               kind: MXLNote.Kind(value: written.kind),
                                               dot: Array(repeating: MXLEmptyPlacement(printStyle: MXLPrintStyle()), count: written.dots),
                                               notations: notationItems.isEmpty ? [] : [MXLNotations(items: notationItems)])))
            }
        }

        return items
    }

    // A trill, mordent or single tremolo. A trill's or mordent's execution
    // goes into its `trill-sound`: `start-note` from its start (`upper` for
    // the partner above, `below` for the partner below), `trill-step` from
    // its partner rule, and `beats` (counting the notes from the start note)
    // or `last-beat` from its extent; a mordent sounding its partner twice is
    // `long`. A written partner is an `<accidental-mark>` when it's the
    // diatonic neighbor. A rate, a diatonic partner rule and a written
    // partner further away are dropped.
    private func _ornamentItems(_ ornament: NoteTable<BeatTime, Pitch>.Ornament,
                                tone: ExportTone,
                                duration: BeatDuration) -> [MXLNotations.Item] {
        let content: MXLOrnaments.Content
        var accidentalMarks: [MXLAccidentalMark] = []

        switch (ornament.sign, ornament.partner) {
        case (nil, _):
            _report(.droppedOrnament)
            return []

        case let (.tremolo(kind)?, .repeat):
            if !(ornament.execution?.isEmpty ?? true) {
                _report(.droppedExecution)
            }

            switch kind {
            case let .measured(strokes):
                let marks = UInt(min(8, max(0, Int(strokes.uintValue) - Int(convertToFlagCount(duration)))))

                content = .tremolo(MXLTremolo(value: MXLTremoloMarks(uintValue: marks).require(), kind: .single))

            case .unmeasured:
                content = .tremolo(MXLTremolo(value: MXLTremoloMarks(uintValue: 3).require(), kind: .unmeasured))
            }

        case (.tremolo, _):
            return []

        case let (sign?, .step(side, written)):
            let execution = ornament.execution
            let isLongMordent = if sign == .mordent, case let .count(count)? = execution?.extent { count.uintValue == 2 } else { false }
            let trillSound = _trillSound(execution, sign: sign, side: side, skipsExtent: isLongMordent)

            if let written {
                if written.pitchClass.letter == Self._neighbor(of: tone.pitch.pitchClass.letter, side: side) {
                    accidentalMarks.append(MXLAccidentalMark(value: convertToMusicXMLAccidentalValue(written.pitchClass.accidental)))
                } else {
                    _report(.droppedExecution)
                }
            }

            switch (sign, side) {
            case (.mordent, .above):
                content = .invertedMordent(MXLMordent(trillSound: trillSound, isLong: isLongMordent ? true : nil))

            case (.mordent, .below):
                content = .mordent(MXLMordent(trillSound: trillSound, isLong: isLongMordent ? true : nil))

            default:
                content = .trillMark(MXLEmptyTrillSound(trillSound: trillSound))
            }

        default:
            return []
        }

        return [.ornaments(MXLOrnaments(entries: [.init(content: content, accidentalMarks: accidentalMarks)]))]
    }

    private func _report(_ kind: ExternWarning.Kind) {
        warnings.add(kind, workIndex: workIndex)
    }

    private func _trillSound(_ execution: NoteTable<BeatTime, Pitch>.OrnamentExecution?,
                             sign: NoteTable<BeatTime, Pitch>.Ornament.Sign,
                             side: PartnerSide,
                             skipsExtent: Bool) -> MXLTrillSound {
        guard let execution
        else { return MXLTrillSound() }

        let startNote: MXLStartNote? = switch execution.startNote {
        case .main:
            .main

        case .partner:
            side == .above ? .upper : .below

        case nil:
            nil
        }

        let trillStep: MXLTrillStep? = switch execution.partnerRule {
        case .diatonic,
             nil:
            nil

        case .halfStep:
            .half

        case .wholeStep:
            .whole
        }

        if execution.partnerRule == .diatonic || execution.rate != nil {
            _report(.droppedExecution)
        }

        var beats: MXLTrillBeats?
        var lastBeat: MXLPercent?

        switch skipsExtent ? nil : execution.extent {
        case let .count(count)?:
            let startsOnPartner = (execution.startNote ?? (sign == .trill ? .partner : .main)) == .partner
            let notes = Int(count.uintValue) * 2 - (startsOnPartner ? 1 : 0)

            beats = MXLTrillBeats(max(2, notes))

        case let .span(proportion)?:
            lastBeat = proportion.numberValue.doubleValue * 100

        case nil:
            break
        }

        return MXLTrillSound(startNote: startNote, trillStep: trillStep, beats: beats, lastBeat: lastBeat)
    }
}
