// © 2026 John Gary Pusey (see LICENSE.md)

internal import Foundation
internal import IvorGMN
internal import IvorModel
internal import IvorTiming

private import XestiTools

// One pass per voice over its `GMNSymbol`s, walking the note/chord/rest
// cases directly against the AST: duration resolution (sticky base,
// non-sticky dots) and pitch resolution (sticky octave, context-free
// accidental) inline, `$variable` reference splicing
// inline with a cycle guard (`_expandVariable`/`expandedSymbols`), and tied
// notes/chords coalesced into a single table entry via `Context`'s
// `pendingNote`/`tieArmed` slots rather than as a separate post-pass over an
// intermediate event stream. A `\grace` body becomes a grace figure, and the
// ornament, tremolo, roll and fermata tags shape the ornaments of the notes
// they cover (see `Guido.Importer.Walker+Ornaments`). Cue notes remain out
// of scope: they stay inert, contributing nothing beyond closing out
// whatever note/chord they interrupt. Every other bodied tag is a
// transparent wrapper: its body is walked as if the tag weren't there, so
// the notes it covers land in the table same as unwrapped ones.
//
// `$variable` expansion has no access to `GMNVariable`'s declaration-time
// symbol stash (an `internal` property of `IvorGMN`, invisible outside
// it), so it takes a different, arguably more faithful route: it
// re-lexes the variable's raw string body at each reference, prefixed by
// every other declared variable's own text so a nested `$variable`
// reference inside it still resolves — guidolib itself re-lexes a
// variable's raw text inline at each reference point, rather than
// resolving it once up front.
extension Guido.Importer {

    // MARK: Internal Nested Types

    internal struct Walker {

        // MARK: Internal Initializers

        internal init(variables: [GMNVariable.Name: GMNVariable]) {
            self.declarationsText = Self._declarationsText(variables)
            self.variables = variables
        }

        // MARK: Private Instance Properties

        private let declarationsText: String
        private let variables: [GMNVariable.Name: GMNVariable]
    }
}

// MARK: -

extension Guido.Importer.Walker {

    // MARK: Internal Instance Methods

    internal func expandedSymbols(_ name: GMNVariable.Name) -> [GMNSymbol] {
        guard case let .string(text)? = variables[name]?.value,
              let (score, _) = try? Guido.BaseParser().parse(Data("\(declarationsText) [ \(text) ]".utf8)),
              let voice = score.voices.first
        else { return [] }

        return voice.symbols
    }

    // Rolled chords are numbered from `firstArpeggioGroup`, so that each
    // voice's rolls stay apart from the others'.
    internal func walk(_ voice: Guido.Voice,
                       firstArpeggioGroup: UInt = 1) throws(Guido.Error) -> Guido.Importer.Context {
        var context = Guido.Importer.Context()
        var inProgressVariableNames: Set<GMNVariable.Name> = []

        context.nextArpeggioGroup = firstArpeggioGroup

        try _walk(voice.symbols, &context, &inProgressVariableNames)

        Self.moveGraceAfterPending(&context)

        try context.flushPendingNote()

        context.heldTies.end(in: &context.noteTable)

        return context
    }

    // MARK: Private Type Properties

    // The ten standard dynamic levels `convertToDynamic(_:)` recognizes, in
    // rising order, so a ramp's one-step shift can locate its starting level
    // and move to its neighbor.
    private static let dynamicScale: [Dynamic] = [.pppp, .ppp, .pp, .p, .mp, .mf, .f, .ff, .fff, .ffff]

    // MARK: Private Type Methods

    // A fermata is ornamentation, not an extra (see `_handleTag`).
    private static func _articulationExtra(_ articulation: GMNArticulation) -> Extra? {
        switch articulation.kind {
        case .accent:
            .accent

        case .bow:
            switch articulation.type?.lowercased() {
            case "down":
                .downBow

            case "up":
                .upBow

            default:
                Extra(name: Extra.articulation.name,
                      values: [.string("bow")])
            }

        case .fermata:
            nil

        case .harmonic:
            .harmonic

        case .marcato:
            .marcato

        case .pizzicato:
            convertToPizzicatoExtra(articulation.type)

        case .staccato:
            .staccato

        case .tenuto:
            .tenuto
        }
    }

    // The two endpoints of a ramp are inserted plainly (`.rampBoundary`),
    // left for `DynamicMap`'s own linear interpolation to connect, rather
    // than the reassert-then-insert step `_handleIntensity` uses — a ramp is
    // a glide, not an instant change. A zero-length ramp (an empty `.whole`
    // body, or a `.begin`/`.end` pair with nothing between) contributes
    // nothing: there is no span left to glide across.
    private static func _closeDynamicRamp(direction: GMNDynamicRamp.Direction,
                                          startBeatTime: BeatTime,
                                          startDynamic: Dynamic,
                                          endBeatTime: BeatTime,
                                          _ context: inout Guido.Importer.Context) {
        guard endBeatTime != startBeatTime
        else { return }

        let endDynamic = _shifted(startDynamic, direction: direction)

        context.dynamicEvents.append(Guido.Importer.Context.DynamicEvent(beatTime: startBeatTime,
                                                                         dynamic: startDynamic,
                                                                         kind: .rampBoundary))
        context.dynamicEvents.append(Guido.Importer.Context.DynamicEvent(beatTime: endBeatTime,
                                                                         dynamic: endDynamic,
                                                                         kind: .rampBoundary))

        context.lastDynamic = endDynamic
    }

    private static func _declarationsText(_ variables: [GMNVariable.Name: GMNVariable]) -> String {
        variables.values.map { _declarationText($0) }.joined(separator: " ")
    }

    private static func _declarationText(_ variable: GMNVariable) -> String {
        let value = switch variable.value {
        case let .floating(number):
            "\(number)"

        case let .integer(number):
            "\(number)"

        case let .string(text):
            "\"\(_escaped(text))\""
        }

        return "$\(variable.name.stringValue) = \(value);"
    }

    private static func _escaped(_ text: String) -> String {
        text.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    private static func _handleChord(_ chord: GMNChord,
                                     _ context: inout Guido.Importer.Context) throws(Guido.Error) {
        let attackTime = context.currentBeatTime
        let members = try resolveChordMembers(chord, &context)
        var notes = Guido.Chord(notes: members.map(\.note)).notes
        let ornaments = takeOrnaments(&notes, &context)
        let maxDuration = notes.map { convertToBeatDuration($0.duration) }.max() ?? .zero

        try context.considerTie(notes,
                                tiedIndices: Set(members.indices.filter { members[$0].isTied }),
                                attackTime: attackTime,
                                ornaments: ornaments)

        context.advance(maxDuration)
    }

    private static func _handleIntensity(_ intensity: GMNIntensity,
                                         _ context: inout Guido.Importer.Context) {
        guard let dynamic = convertToDynamic(intensity.type) else {
            context.dynamicEvents.append(Guido.Importer.Context.DynamicEvent(beatTime: context.currentBeatTime,
                                                                             dynamic: context.lastDynamic,
                                                                             kind: .step,
                                                                             mark: intensity.type))

            return
        }

        context.dynamicEvents.append(Guido.Importer.Context.DynamicEvent(beatTime: context.currentBeatTime,
                                                                         dynamic: dynamic,
                                                                         kind: .step))

        context.lastDynamic = dynamic
    }

    private static func _handleNote(_ note: GMNNote,
                                    _ context: inout Guido.Importer.Context) throws(Guido.Error) {
        let attackTime = context.currentBeatTime
        var notes = try [resolveNote(note, &context)]
        let ornaments = takeOrnaments(&notes, &context)
        let bdur = convertToBeatDuration(notes[0].duration)

        try context.considerTie(notes,
                                attackTime: attackTime,
                                ornaments: ornaments)

        context.advance(bdur)
    }

    private static func _handleRest(_ rest: GMNRest,
                                    _ context: inout Guido.Importer.Context) throws(Guido.Error) {
        let resolved = try Guido.Rest(duration: resolveRestDuration(rest, &context))
        let duration = convertToBeatDuration(resolved.duration)

        placeBeforeRest(duration: duration, &context)

        try context.flushPendingNote()

        context.heldTies.end(in: &context.noteTable)

        context.lastEvent = (attack: context.currentBeatTime, duration: duration)
        context.tieArmed = false
        context.advance(duration)
    }

    // One step along `dynamicScale` in the given direction, clamped at
    // either end — a ramp beyond `\ffff` stays `\ffff`, one beyond `\pppp`
    // stays `\pppp`, rather than producing no shift at all.
    private static func _shifted(_ dynamic: Dynamic,
                                 direction: GMNDynamicRamp.Direction) -> Dynamic {
        guard let index = dynamicScale.firstIndex(of: dynamic)
        else { return dynamic }

        let shift = direction == .crescendo ? 1 : -1
        let clampedIndex = min(max(index + shift, 0), dynamicScale.count - 1)

        return dynamicScale[clampedIndex]
    }

    private static func _slurExtra(_ extra: Extra, ident: GMNTag.Ident?) -> Extra {
        guard let ident
        else { return extra }

        return Extra(name: extra.name, values: [.string("\(ident.uintValue)")])
    }

    // MARK: Private Instance Methods

    private func _expandVariable(_ name: GMNVariable.Name,
                                 _ context: inout Guido.Importer.Context,
                                 _ inProgressVariableNames: inout Set<GMNVariable.Name>) throws(Guido.Error) {
        guard !inProgressVariableNames.contains(name)
        else { throw Guido.Error.circularVariableReference(name) }

        inProgressVariableNames.insert(name)

        defer { inProgressVariableNames.remove(name) }

        try _walk(expandedSymbols(name), &context, &inProgressVariableNames)
    }

    // A ramp's own two endpoints, since `GMNDynamicRamp` carries only a
    // direction and no target level, are the level in effect when the ramp
    // opens and one step further along `dynamicScale` in that direction —
    // the same "just get louder/softer from here" reading a performer gives
    // a bare hairpin with no `f`/`p` written at its point. An explicit
    // `\intensity` mark inside the ramp's own span (nested in its `.whole`
    // body, or written between a `.begin`/`.end` pair) still lands its own,
    // separate event at its own beat, and `DynamicMap`'s linear
    // interpolation threads straight through it.
    private func _handleDynamicRamp(_ ramp: GMNDynamicRamp,
                                    _ context: inout Guido.Importer.Context,
                                    _ inProgressVariableNames: inout Set<GMNVariable.Name>) throws(Guido.Error) {
        switch ramp.span {
        case .begin:
            context.pendingDynamicRamps[ramp.ident] = (beatTime: context.currentBeatTime,
                                                       dynamic: context.lastDynamic,
                                                       direction: ramp.direction)

        case .end:
            guard let pending = context.pendingDynamicRamps.removeValue(forKey: ramp.ident)
            else { return }

            Self._closeDynamicRamp(direction: pending.direction,
                                   startBeatTime: pending.beatTime,
                                   startDynamic: pending.dynamic,
                                   endBeatTime: context.currentBeatTime,
                                   &context)

        case .whole:
            let startBeatTime = context.currentBeatTime
            let startDynamic = context.lastDynamic

            try _walk(ramp.body, &context, &inProgressVariableNames)

            Self._closeDynamicRamp(direction: ramp.direction,
                                   startBeatTime: startBeatTime,
                                   startDynamic: startDynamic,
                                   endBeatTime: context.currentBeatTime,
                                   &context)
        }
    }

    // An ornament, tremolo, roll or fermata tag: one with a body applies to
    // every note or chord in it, as does one opening a span (`\trillBegin`)
    // until its end; a bodiless one waits for the next note or chord, except
    // a fermata, which marks the last event (see
    // `placeBodilessFermata(_:_:)`).
    private func _handleOrnamentTag(_ tag: GMNTag,
                                    _ context: inout Guido.Importer.Context,
                                    _ inProgressVariableNames: inout Set<GMNVariable.Name>) throws(Guido.Error) {
        switch tag.span {
        case .begin:
            context.activeOrnamentTags.append(tag)

        case .end:
            Self.closeOrnamentSpan(tag, &context)

        case .whole where tag.body.isEmpty:
            if case let .articulation(fermata) = tag {
                Self.placeBodilessFermata(fermata, &context)
            } else {
                context.stagedOrnamentTags.append(tag)
            }

        case .whole:
            let depth = context.activeOrnamentTags.count

            context.activeOrnamentTags.append(tag)

            try _walk(tag.body, &context, &inProgressVariableNames)

            if context.activeOrnamentTags.count > depth {
                context.activeOrnamentTags.remove(at: depth)
            }
        }
    }

    // Not `static`, unlike its neighbors: a `\crescendo`/`\diminuendo` in
    // `.whole` span form owns its covered notes as its own tag body, which
    // has to be walked through the very same `_walk` (for `$variable`
    // splicing and cycle detection) that called this method in the first
    // place.
    private func _handleTag(_ tag: GMNTag,
                            _ context: inout Guido.Importer.Context,
                            _ inProgressVariableNames: inout Set<GMNVariable.Name>) throws(Guido.Error) {
        switch tag {
        // `\accent<...>{C}`-style tags scope their mark over a `body:` of
        // note symbols (guidolib's own template shape for every kind but
        // `\stacc` — see `convertToGuidoTag(_:body:)` on the export side),
        // so the tag's own body has to be walked right here rather than
        // just staging the flag and falling through to `default:`'s flush
        // — a real gap fixed after the export side first exposed it via a
        // round-trip crash: without this, a body-wrapped note was never
        // reached at all.
        case let .articulation(articulation) where articulation.kind == .fermata:
            try _handleOrnamentTag(tag, &context, &inProgressVariableNames)

        case let .articulation(articulation):
            if let extra = Self._articulationExtra(articulation) {
                context.pendingNoteExtras.append(extra)
            }

            try _walk(articulation.body, &context, &inProgressVariableNames)

        case .arpeggio,
             .tremolo:
            try _handleOrnamentTag(tag, &context, &inProgressVariableNames)

        // A bar line, a meter (which starts a bar) and a key signature are
        // the only bodiless tags that leave the pending note and its tie
        // alone: the exporter writes them between the two halves of a note
        // tied across a bar line (or a key change), and the tie has to
        // survive them. A fermata on a bar line is a mark over the last
        // event before it.
        case .barLine:
            if let meter = context.meter {
                context.barlines.append((context.currentBeatTime, meter, nil))
            }

            Self.placeAtBarLine(&context)

        case let .breathMark(breathMark):
            context.pendingNoteExtras.append(.breathMark)

            try _walk(breathMark.body, &context, &inProgressVariableNames)

        // A cue note's body is an alternate, non-sounding passage, so it
        // stays inert. It ends any tie it interrupts.
        case .cue:
            try context.flushPendingNote()

            context.heldTies.end(in: &context.noteTable)

            context.tieArmed = false

        // A grace figure takes no time of its own: its body becomes the
        // figure before the next note (see `stageGrace(_:_:_:)`). It breaks
        // a tie it interrupts, but leaves the pending note pending, so that a
        // figure before a rest can still follow it.
        case let .grace(grace):
            context.pendingTiedIndices = []
            context.tieArmed = false

            try stageGrace(grace, &context, &inProgressVariableNames)

        case let .dynamicRamp(ramp):
            try context.flushPendingNote()

            context.tieArmed = false

            try _handleDynamicRamp(ramp, &context, &inProgressVariableNames)

        case let .fingering(fingering):
            context.pendingNoteExtras.append(Extra(name: Extra.fingering.name, values: [.string(fingering.text)]))

            try _walk(fingering.body, &context, &inProgressVariableNames)

        case let .instrument(instrument):
            try context.flushPendingNote()

            context.tieArmed = false

            context.instrumentEvents.append((beatTime: context.currentBeatTime,
                                             instrument: convertToInstrument(instrument),
                                             tag: instrument))

            if context.instrumentName == nil {
                context.instrumentName = instrument.instrumentName
            }

        case let .intensity(intensity):
            try context.flushPendingNote()

            context.tieArmed = false

            Self._handleIntensity(intensity, &context)

        case let .key(key):
            context.recordKey(key)

        case let .meter(meter):
            context.recordMeter(meter)

        case let .ornament(ornament) where ornament.kind == .turn:
            context.pendingNoteExtras.append(.turn)

            try _walk(ornament.body, &context, &inProgressVariableNames)

        case .ornament:
            try _handleOrnamentTag(tag, &context, &inProgressVariableNames)

        // Guido has only the damper pedal: `\pedalOn` and `\pedalOff` put it
        // down and let it up at the current beat. A body, if any, is walked
        // as for any other wrapping tag.
        case let .pedal(pedal):
            context.sustainTable.insert(time: context.currentBeatTime,
                                        level: pedal.kind == .on ? .down : .up)

            try _walk(pedal.body, &context, &inProgressVariableNames)

        // The whole-tag `\slur<...>{...}` bracket form — as opposed to the
        // open-span `Begin`/`End` pair the two cases below handle — needs
        // no id: `body` alone unambiguously delimits the span, so the
        // first note walked from it is marked as the start and whichever
        // note is left pending once the whole body has been walked (the
        // last one) is marked as the end, the same "mutate the current
        // pending note" pattern the `.end`-span case below uses. Only
        // wired on import — `Guido.Exporter` always writes the open-span
        // ident form instead, so this direction is read-only, matching
        // how `dynamicMark`'s own MusicXML `otherDynamics`-vs-fixed-case
        // split reads a wider vocabulary than it writes.
        case let .slur(slur) where slur.span == .whole:
            context.pendingNoteExtras.append(.slurStart)

            try _walk(slur.body, &context, &inProgressVariableNames)

            if var pending = context.pendingNote {
                pending.extras.append(.slurEnd)
                context.pendingNote = pending
            }

        case let .slur(slur) where slur.span == .begin:
            context.pendingNoteExtras.append(Self._slurExtra(.slurStart, ident: slur.ident))

        case let .slur(slur) where slur.span == .end:
            // The note this closes is still `pendingNote` (mirrors ABC's own
            // slur-end handling) — appended directly rather than staged for
            // the next note.
            if var pending = context.pendingNote {
                pending.extras.append(Self._slurExtra(.slurEnd, ident: slur.ident))
                context.pendingNote = pending
            }

        case let .tempo(tempo):
            try context.flushPendingNote()

            context.tieArmed = false

            if let metronome = tempo.metronome,
               let tempoValue = convertToTempo(metronome) {
                context.tempoEvents.append((beatTime: context.currentBeatTime,
                                            tempo: tempoValue,
                                            text: tempo.tempo.nilIfEmpty))
            }

        case let .tie(tie) where tie.span == .end:
            context.tieArmed = true

        // Every other bodied tag (`\beam`, `\tuplet`, `\lyrics`, `\harmony`,
        // and the rest) is a transparent wrapper around the notes it covers
        // — those notes are its whole reason for having a body — so its body
        // is walked exactly as if the wrapping tag were not there. A gap
        // fixed after a real score (Fauré's "Après un rêve", almost entirely
        // `\lyrics`- and `\beam`-wrapped) round-tripped through an import
        // with two of its three voices silently empty.
        default:
            if !tag.body.isEmpty {
                try _walk(tag.body, &context, &inProgressVariableNames)
            } else {
                try context.flushPendingNote()

                context.tieArmed = false
            }
        }
    }

    // Every tag goes through `_handleTag`, which reads a `\slur` in both its
    // `.whole` bracket form and its open-span `Begin`/`End` form, and an
    // articulation, ornament, fingering or breath mark whether it wraps its
    // notes in a body or precedes the note it marks.
    private func _walk(_ symbols: [GMNSymbol],
                       _ context: inout Guido.Importer.Context,
                       _ inProgressVariableNames: inout Set<GMNVariable.Name>) throws(Guido.Error) {
        for symbol in symbols {
            switch symbol {
            case let .chord(chord):
                try Self._handleChord(chord, &context)

            case let .note(note):
                try Self._handleNote(note, &context)

            case let .rest(rest):
                try Self._handleRest(rest, &context)

            case .tablature:
                throw Guido.Error.unsupportedEvent(symbol)

            case let .tag(tag):
                try _handleTag(tag, &context, &inProgressVariableNames)

            case let .variable(name):
                try _expandVariable(name, &context, &inProgressVariableNames)
            }
        }
    }
}
