// © 2026 John Gary Pusey (see LICENSE.md)

internal import IvorABC
internal import IvorModel
internal import IvorTiming

private import XestiTools

// Routes one tune's body into one `[Item]` stream per voice (ported from
// upstream's own voice-routing pass), builds each voice's repeat/parts
// replay order via `ABC.Importer.Plan`, and streams that order once,
// delegating duration/tuplet/broken-rhythm resolution to
// `ABC.Importer.Rhythm`, written- and sounding-pitch resolution to
// `ABC.Importer.PitchFolder` (a fixed `transpose=`/`octave=`/ottava fold —
// this importer has always walked an already playback-optimized result, so
// folding is baseline behavior, not new), and `m:` macro expansion to
// `ABC.Importer.MacroTable`.
//
// Ties and broken rhythm both need a look at the symbol *after* the one just
// built — a tie may or may not continue into the next matching note/chord;
// a `>`/`<` marker rescales the note/chord that already preceded it. Both
// are handled by deferring a just-built note/chord/rest in `Context`'s
// `pendingEvent` until the walker knows what follows, exactly the
// one-step-deferred-commit shape Guido's own tie handling uses —
// extended here to also gate `currentBeatTime`'s advance, since a
// broken-rhythm marker retroactively changes how long the pending event
// actually sounds. Bar lines and variant-ending markers are deliberately
// *not* flush triggers: upstream drops both from its event stream before its
// own tie-coalescing pass ever runs, so a tie legitimately spans a bar line
// or a non-matching ending's boundary. Every other item — a field, in
// particular — does flush, since those remain in upstream's stream through
// its coalescing pass and are only dropped afterward.
extension ABC.Importer {

    // MARK: Internal Nested Types

    internal struct Walker {

        // MARK: Internal Initializers

        internal init() {
        }

        // MARK: Private Instance Properties

        private let macroTable = MacroTable()
        private let pitchFolder = PitchFolder()
        private let rhythm = Rhythm()
    }
}

// MARK: -

extension ABC.Importer.Walker {

    // MARK: Internal Instance Methods

    // Routes `tune`'s body into one voice per declared `V:` id (plus the
    // always-present implicit voice), each voice's own item stream prefixed
    // by `fileHeader` and `tune.header`'s own non-`V:` entries — the same
    // header-then-body event prefixing upstream performs for every voice,
    // folded here into ordinary item processing rather than a separate
    // seed-state pass, so a header `K:`/`M:`/`L:`/`Q:` field is resolved by
    // exactly the same code path as its mid-body counterpart.
    internal func walk(_ tune: ABCTune,
                       fileHeader: [ABCHeaderEntry]) throws(ABC.Error) -> [(identity: ABC.Voice?, context: ABC.Importer.Context)] {
        let accumulators = Self._routed(tune, fileHeader: fileHeader)
        var results: [(identity: ABC.Voice?, context: ABC.Importer.Context)] = []

        for accumulator in accumulators {
            let plan = ABC.Importer.Plan(items: accumulator.items)
            let context = try _walk(accumulator.items,
                                    plan.ranges(),
                                    voiceClef: accumulator.identity?.clef)

            results.append((identity: accumulator.identity, context: context))
        }

        return results
    }

    // MARK: Private Nested Types

    private struct Accumulator {

        // MARK: Fileprivate Instance Properties

        fileprivate var identity: ABC.Voice?
        fileprivate var items: [ABC.Importer.Item] = []
    }

    // MARK: Private Type Methods

    private static func _merged(_ existing: ABC.Voice?,
                                _ voice: ABC.Voice) -> ABC.Voice {
        guard let existing
        else { return voice }

        return ABC.Voice(id: voice.id,
                         clef: voice.clef ?? existing.clef,
                         properties: existing.properties.merging(voice.properties) { _, new in new }).require()
    }

    // Routes `tune`'s body into one accumulator per voice, mirroring
    // upstream's own voice router: the implicit voice always exists (index
    // 0), a `V:` field (header or inline) merges into that id's declared
    // identity and, in the body, switches which accumulator subsequent
    // items land in. Directives are dropped entirely — never even
    // represented as an `Item`.
    private static func _routed(_ tune: ABCTune,
                                fileHeader: [ABCHeaderEntry]) -> [Accumulator] {
        var accumulators: [Accumulator] = []
        var indexByID: [ABC.Voice.ID?: Int] = [:]
        var currentID: ABC.Voice.ID?

        func index(for id: ABC.Voice.ID?) -> Int {
            if let existing = indexByID[id] {
                return existing
            }

            let newIndex = accumulators.count

            accumulators.append(Accumulator())
            indexByID[id] = newIndex

            return newIndex
        }

        func applyVoiceField(_ voice: ABC.Voice,
                             activating: Bool) {
            let idx = index(for: voice.id)

            accumulators[idx].identity = _merged(accumulators[idx].identity, voice)

            if activating {
                currentID = voice.id
            }
        }

        _ = index(for: nil)

        // Every voice, not just the implicit one, sees the file and tune
        // header's own fields first — mirroring header content being
        // prefixed onto *every* voice's stream upstream — so a header
        // `L:`/`K:` seeds every voice's `Context` identically, including a
        // voice that isn't even declared until partway through the body.
        var headerItems: [ABC.Importer.Item] = []

        for entry in fileHeader + tune.header {
            guard case let .field(field) = entry
            else { continue }

            if case let .voice(voice) = field {
                applyVoiceField(voice, activating: false)
            } else {
                headerItems.append(.field(field))
            }
        }

        for entry in tune.body {
            switch entry {
            case .directive:
                continue

            case let .field(.voice(voice)):
                applyVoiceField(voice, activating: true)

            case let .field(field):
                accumulators[index(for: currentID)].items.append(.field(field))

            case let .symbols(symbols):
                for symbol in symbols {
                    switch symbol {
                    case let .inlineField(.voice(voice)):
                        applyVoiceField(voice, activating: true)

                    case let .inlineField(field):
                        accumulators[index(for: currentID)].items.append(.field(field))

                    default:
                        accumulators[index(for: currentID)].items.append(.symbol(symbol))
                    }
                }
            }
        }

        for index in accumulators.indices {
            accumulators[index].items.insert(contentsOf: headerItems, at: 0)
        }

        return accumulators
    }
}

// MARK: -

extension ABC.Importer.Walker {

    // MARK: Private Instance Methods

    private func _apply(_ field: ABCField,
                        _ context: inout ABC.Importer.Context) throws(ABC.Error) {
        try _commitPending(&context)

        switch field {
        case let .key(keySignature):
            context.barAccidentals = [:]
            context.keyAccidentals = keySignature.accidentals

            if let clef = pitchFolder.clef(from: keySignature) {
                context.activeClef = clef
            }

        case let .macro(macro):
            context.macros.append(macro)

        case let .meter(meter):
            context.meter = meter

            if !context.hasExplicitUnitNoteLength {
                context.unitNoteLength = rhythm.defaultUnitNoteLength(meter)
            }

        case let .tempo(tempo):
            if let converted = convertToTempo(tempo) {
                context.tempoEvents.append((beatTime: context.currentBeatTime, tempo: converted))
            }

        case let .unitNoteLength(length):
            context.unitNoteLength = (length.numerator, length.denominator)
            context.hasExplicitUnitNoteLength = true

        default:
            break
        }
    }

    private func _commitPending(_ context: inout ABC.Importer.Context) throws(ABC.Error) {
        guard let pending = context.pendingEvent
        else { return }

        switch pending.event {
        case let .chord(chord):
            for note in chord.notes {
                let pitch = try convertToStandardPitch(note.pitch)

                try context.noteTable.insert(attack: pending.attack,
                                             duration: convertToBeatDuration(note.duration),
                                             pitch: pitch)
            }

        case let .note(note):
            let pitch = try convertToStandardPitch(note.pitch)

            try context.noteTable.insert(attack: pending.attack,
                                         duration: convertToBeatDuration(note.duration),
                                         pitch: pitch)

        case .rest:
            break
        }

        try context.advance(convertToBeatDuration(rhythm.advanceDuration(pending.event)))
        context.pendingEvent = nil
    }

    // The new event's attack time can only be known *after* any commit
    // below, since committing the still-pending event is what advances
    // `context.currentBeatTime` past it — computing the attack up front,
    // before knowing whether this event ties onto (rather than replaces)
    // the pending one, would stamp every non-tying event with whatever time
    // was current before its predecessor had even been timed.
    private func _considerTie(_ event: ABC.Event,
                              _ context: inout ABC.Importer.Context) throws(ABC.Error) {
        if context.tieArmed,
           let pending = context.pendingEvent,
           let merged = rhythm.merged(pending.event, event) {
            context.pendingEvent = (attack: pending.attack, event: merged)
        } else {
            try _commitPending(&context)
            context.pendingEvent = (attack: context.currentBeatTime, event: event)
        }

        context.tieArmed = event.tie != nil
    }

    private func _handleChord(_ chord: ABCChord,
                              _ context: inout ABC.Importer.Context) throws(ABC.Error) {
        let combinedScale = rhythm.multiplied(rhythm.consumedScale(&context),
                                              (chord.length.numerator, chord.length.denominator))
        var notes: [ABC.Note] = []

        for note in chord.notes {
            let writtenPitch = pitchFolder.resolvedWrittenPitch(note.pitch, &context)
            let foldedPitch = try pitchFolder.foldedPitch(writtenPitch, context.activeClef)
            let duration = ABC.Duration(written: note.length, unitNoteLength: context.unitNoteLength) * combinedScale

            notes.append(ABC.Note(duration: duration, pitch: foldedPitch, tie: note.tie))
        }

        try _considerTie(.chord(ABC.Chord(notes: notes, tie: chord.tie)), &context)
    }

    // A dynamics decoration (`!mf!`, `!ff!`, …) is an instant change, so it
    // gets `.step`. `!<(!`/`!<)!` (crescendo) and `!>(!`/`!>)!` (diminuendo)
    // hairpins pair by direction alone — ABC decorations carry no
    // identifier the way Guido's `\crescBegin:1`/`\crescEnd:1` do — so at
    // most one hairpin of each direction can be open at a time; opening a
    // second of the same direction before the first closes silently
    // replaces it. The alternate spelled-out names (`crescendo(`,
    // `diminuendo)`, …) are recognized case-insensitively alongside the
    // symbolic ones. Flushes `pendingEvent` first, like `_apply(_:_:)` does:
    // a *closing* hairpin marker is written right after the notes it covers,
    // so `context.currentBeatTime` has to reflect them — but they may still
    // be sitting in `pendingEvent`, undecided until the walk sees whether the
    // next item ties onto them, unless this flushes them itself.
    private func _handleDecoration(_ decoration: ABCDecoration,
                                   _ context: inout ABC.Importer.Context) throws(ABC.Error) {
        try _commitPending(&context)

        if let dynamic = convertToDynamic(decoration.name) {
            context.dynamicEvents.append(ABC.Importer.Context.DynamicEvent(beatTime: context.currentBeatTime,
                                                                           dynamic: dynamic,
                                                                           kind: .step))

            context.lastDynamic = dynamic

            return
        }

        switch decoration.name.stringValue.lowercased() {
        case "<(",
             "crescendo(":
            context.pendingCrescendo = (beatTime: context.currentBeatTime, dynamic: context.lastDynamic)

        case "<)",
             "crescendo)":
            Self._closeDynamicRamp(context.pendingCrescendo,
                                   direction: .crescendo,
                                   endBeatTime: context.currentBeatTime,
                                   &context)

            context.pendingCrescendo = nil

        case ">(",
             "diminuendo(":
            context.pendingDiminuendo = (beatTime: context.currentBeatTime, dynamic: context.lastDynamic)

        case ">)",
             "diminuendo)":
            Self._closeDynamicRamp(context.pendingDiminuendo,
                                   direction: .diminuendo,
                                   endBeatTime: context.currentBeatTime,
                                   &context)

            context.pendingDiminuendo = nil

        default:
            break
        }
    }

    private func _handleNote(_ note: ABCNote,
                             _ context: inout ABC.Importer.Context) throws(ABC.Error) {
        let scale = rhythm.consumedScale(&context)
        let writtenPitch = pitchFolder.resolvedWrittenPitch(note.pitch, &context)
        let foldedPitch = try pitchFolder.foldedPitch(writtenPitch, context.activeClef)
        let duration = ABC.Duration(written: note.length, unitNoteLength: context.unitNoteLength) * scale

        try _considerTie(.note(ABC.Note(duration: duration, pitch: foldedPitch, tie: note.tie)), &context)
    }

    private func _handleRest(_ rest: ABCRest,
                             _ context: inout ABC.Importer.Context) throws(ABC.Error) {
        let scale = rhythm.consumedScale(&context)
        let base: ABC.Duration = switch rest {
        case let .multiMeasure(_, measureCount):
            rhythm.measureDuration(context.meter) * (measureCount.uintValue, 1)

        case let .regular(_, length):
            ABC.Duration(written: length, unitNoteLength: context.unitNoteLength)
        }

        try _considerTie(.rest(ABC.Rest(duration: base * scale)), &context)
    }

    private func _process(_ item: ABC.Importer.Item,
                          _ context: inout ABC.Importer.Context) throws(ABC.Error) {
        switch item {
        case let .field(field):
            try _apply(field, &context)

        case let .symbol(symbol):
            try _process(symbol, &context)
        }
    }

    // Every case here that can never reach the note table (attachments,
    // grace notes, beam-breaks, voice overlays, typesetting spacers, `U:`
    // shorthand) is a deliberate no-op. Bar lines and variant endings are
    // also no-ops for the note table but do carry state effects — see the
    // type-level comment on why neither flushes `pendingEvent`.
    private func _process(_ symbol: ABCSymbol,
                          _ context: inout ABC.Importer.Context) throws(ABC.Error) {
        switch symbol {
        case .annotation,
             .beamBreak,
             .chordSymbol,
             .graceNotes,
             .inlineField,
             .overlay,
             .shorthand,
             .slur,
             .spacer,
             .variantEnding:
            break

        case .barLine:
            context.barAccidentals = [:]

        case let .brokenRhythm(marker):
            if let pending = context.pendingEvent {
                context.pendingEvent = (attack: pending.attack,
                                        event: rhythm.rescaled(pending.event,
                                                               by: rhythm.brokenRhythmFactor(marker, isLeft: true)))
            }

            context.pendingBrokenRhythmRight = rhythm.brokenRhythmFactor(marker, isLeft: false)

        case let .chord(chord):
            try _handleChord(chord, &context)

        case let .decoration(decoration):
            try _handleDecoration(decoration, &context)

        case let .note(note):
            try _handleNote(note, &context)

        case let .rest(rest):
            try _handleRest(rest, &context)

        case let .tuplet(tuplet):
            let resolved = rhythm.resolvedTuplet(tuplet, meter: context.meter)

            context.pendingTuplet = (resolved.beatCount, resolved.noteCount, resolved.affectedCount)
        }
    }

    // Streams `ranges` over `items` once, checking for an active macro
    // match at every symbol position before falling back to ordinary
    // resolution. A matched macro's expansion is fed through the same
    // per-symbol resolution (not re-checked for further macro matches, to
    // keep expansion single-pass), exactly as upstream's own body-symbol
    // walk does.
    private func _walk(_ items: [ABC.Importer.Item],
                       _ ranges: [Range<Int>],
                       voiceClef: ABCClef?) throws(ABC.Error) -> ABC.Importer.Context {
        var context = ABC.Importer.Context()

        context.activeClef = voiceClef

        for range in ranges {
            var index = range.lowerBound

            while index < range.upperBound {
                if case .symbol = items[index] {
                    var lookahead: [ABCSymbol] = []
                    var scan = index

                    while scan < range.upperBound, case let .symbol(symbol) = items[scan] {
                        lookahead.append(symbol)
                        scan += 1
                    }

                    if let match = macroTable.findMatch(lookahead, 0, context.macros) {
                        for expandedSymbol in try macroTable.expand(match) {
                            try _process(expandedSymbol, &context)
                        }

                        index += match.consumedCount
                        continue
                    }
                }

                try _process(items[index], &context)
                index += 1
            }
        }

        try _commitPending(&context)

        return context
    }
}

// MARK: -

extension ABC.Importer.Walker {

    // MARK: Private Nested Types

    // Which way a hairpin decoration ramps. Not exposed beyond this file —
    // ABC has no typed AST payload for a hairpin the way Guido's
    // `GMNDynamicRamp` does, so this exists solely to drive `_shifted(_:direction:)`.
    private enum DynamicRampDirection {
        case crescendo
        case diminuendo
    }

    // MARK: Private Type Properties

    // The ten standard dynamic levels `convertToDynamic(_:)` recognizes, in
    // rising order, so a hairpin's one-step shift can locate its starting
    // level and move to its neighbor.
    private static let dynamicScale: [Dynamic] = [.pppp, .ppp, .pp, .p, .mp, .mf, .f, .ff, .fff, .ffff]

    // MARK: Private Type Methods

    // A hairpin's own two endpoints, since it carries only a direction and
    // no target level, are the level in effect when it opens and one step
    // further along `dynamicScale` in that direction — the same "just get
    // louder/softer from here" reading a performer gives a bare hairpin
    // with no `f`/`p` written at its point. An explicit dynamics decoration
    // written between the pair still lands its own, separate event at its
    // own beat, and `DynamicMap`'s linear interpolation threads straight
    // through it. `pending` is `nil` when a close arrives with no matching
    // open, and the endpoints collapse to nothing when a hairpin opens and
    // closes at the same beat — both are silently skipped, since there is no
    // span left to glide across.
    private static func _closeDynamicRamp(_ pending: (beatTime: BeatTime, dynamic: Dynamic)?,
                                          direction: DynamicRampDirection,
                                          endBeatTime: BeatTime,
                                          _ context: inout ABC.Importer.Context) {
        guard let pending,
              endBeatTime != pending.beatTime
        else { return }

        let endDynamic = _shifted(pending.dynamic, direction: direction)

        context.dynamicEvents.append(ABC.Importer.Context.DynamicEvent(beatTime: pending.beatTime,
                                                                       dynamic: pending.dynamic,
                                                                       kind: .rampBoundary))
        context.dynamicEvents.append(ABC.Importer.Context.DynamicEvent(beatTime: endBeatTime,
                                                                       dynamic: endDynamic,
                                                                       kind: .rampBoundary))

        context.lastDynamic = endDynamic
    }

    // One step along `dynamicScale` in the given direction, clamped at
    // either end — a hairpin beyond `!ffff!` stays `!ffff!`, one beyond
    // `!pppp!` stays `!pppp!`, rather than producing no shift at all.
    private static func _shifted(_ dynamic: Dynamic,
                                 direction: DynamicRampDirection) -> Dynamic {
        guard let index = dynamicScale.firstIndex(of: dynamic)
        else { return dynamic }

        let shift = direction == .crescendo ? 1 : -1
        let clampedIndex = min(max(index + shift, 0), dynamicScale.count - 1)

        return dynamicScale[clampedIndex]
    }
}
