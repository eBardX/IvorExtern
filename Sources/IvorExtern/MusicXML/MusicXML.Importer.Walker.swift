// © 2026 John Gary Pusey (see LICENSE.md)

internal import IvorModel
internal import IvorMusicXML
internal import IvorTiming
internal import IvorTuning

// The `<backup>` / `<forward>` / `<chord>` time-cursor walk, one pass per
// part, over the measures the `Plan` selects — ported from the resolving
// half of upstream's own top-level walk, minus everything that fed the
// score-wide timeline (`<barline>`s and non-sound `<direction>`s), which the
// `Plan` already consumed directly from the AST, and minus tie coalescing,
// which happens inline here via `Context.pendingTies` rather than as a
// post-resolution pass over a flattened event stream (see the type-level
// comment on `Context`).
//
// Every member of a chord shares the chord's onset and duration — the
// duration of its lead note — regardless of any member's own written length;
// this is deliberate and preserved exactly from the current importer.
extension MusicXML.Importer {

    internal struct Walker {

        // MARK: Internal Initializers

        internal init() {
        }

        // MARK: Private Instance Properties

        private let rhythm = MusicXML.Importer.Rhythm()
        private let transposer = MusicXML.Importer.Transposer()
    }
}

// MARK: -

extension MusicXML.Importer.Walker {

    // MARK: Internal Instance Methods

    internal func walk(_ score: MusicXML.Score,
                       order: [Int]) throws(MusicXML.Error) -> [WalkResult] {
        let scoreParts = Self._scorePartsByID(score)
        var results: [WalkResult] = []

        for part in score.parts {
            guard let scorePart = scoreParts[part.id]
            else { continue }

            let context = try _walk(part, order: order)

            results.append(WalkResult(directionDynamicEvents: context.directionDynamicEvents,
                                      panEvents: context.panEvents,
                                      part: MusicXML.Part(part: scorePart, voices: Self._voices(from: context)),
                                      tempoEvents: context.tempoEvents))
        }

        return results
    }

    // MARK: Private Type Properties

    // The ten standard dynamic levels `convertToDynamic(_:)` recognizes, in
    // rising order, so a wedge's one-step shift can locate its starting
    // level and move to its neighbor.
    private static let dynamicScale: [Dynamic] = [.pppp, .ppp, .pp, .p, .mp, .mf, .f, .ff, .fff, .ffff]

    // MARK: Private Type Methods

    // The `<transpose>` active for a note's staff: the note's own staff
    // first, falling back to the part-wide (`number`-less) transpose.
    private static func _activeTranspose(for note: MXLNote,
                                         in context: MusicXML.Importer.Context) -> MXLTranspose? {
        context.transposes[note.staff?.uintValue] ?? context.transposes[nil]
    }

    private static func _apply(_ attributes: MXLAttributes,
                               to context: inout MusicXML.Importer.Context) {
        if let divisions = attributes.divisions {
            context.activeDivisions = divisions.intValue
        }

        for time in attributes.time {
            context.times[time.number?.uintValue] = time
        }

        if case let .transpose(transposes) = attributes.content {
            for transpose in transposes {
                context.transposes[transpose.number?.uintValue] = transpose
            }
        }
    }

    private static func _flushPendingTies(_ context: inout MusicXML.Importer.Context) {
        for (voiceID, pending) in context.pendingTies {
            var table = context.noteTable(forVoice: voiceID)

            for (pitch, entry) in pending {
                table.insert(attack: entry.attack,
                             duration: entry.duration,
                             pitch: pitch)
            }

            context.noteTables[voiceID] = table
        }
    }

    // `<wedge>` carries only a crescendo/diminuendo direction, not a target
    // level, so a wedge's own two endpoints are the level in effect when it
    // opens and one step further along `dynamicScale` in that direction —
    // the same "just get louder/softer from here" reading a performer gives
    // a bare hairpin with no dynamics mark written after it. An explicit
    // `<sound>`/notated `<dynamics>` mark within the wedge's span still
    // lands its own, separate event at its own beat, and `DynamicMap`'s
    // linear interpolation threads straight through it. `type="continue"`
    // (formatting a wedge across a system break) is a transparent pass-
    // through — neither opens nor closes anything — and a `type="stop"`
    // with no matching open, or one that closes at the very beat it opened,
    // is silently skipped: there is no span left to glide across.
    private static func _handleWedge(_ wedge: MXLWedge,
                                     at beatTime: BeatTime,
                                     _ context: inout MusicXML.Importer.Context) {
        switch wedge.kind {
        case .crescendo,
             .diminuendo:
            context.pendingWedges[wedge.number] = (beatTime: beatTime,
                                                   dynamic: context.lastDirectionDynamic,
                                                   kind: wedge.kind)

        case .stop:
            guard let pending = context.pendingWedges.removeValue(forKey: wedge.number),
                  beatTime != pending.beatTime
            else { return }

            let endDynamic = _shifted(pending.dynamic, kind: pending.kind)

            context.directionDynamicEvents.append(MusicXML.Importer.Context.DynamicEvent(beatTime: pending.beatTime,
                                                                                         dynamic: pending.dynamic,
                                                                                         kind: .rampBoundary))
            context.directionDynamicEvents.append(MusicXML.Importer.Context.DynamicEvent(beatTime: beatTime,
                                                                                         dynamic: endDynamic,
                                                                                         kind: .rampBoundary))

            context.lastDirectionDynamic = endDynamic

        case .continue:
            break
        }
    }

    private static func _recordDirectionDynamic(_ dynamic: Dynamic,
                                                at beatTime: BeatTime,
                                                _ context: inout MusicXML.Importer.Context) {
        context.directionDynamicEvents.append(MusicXML.Importer.Context.DynamicEvent(beatTime: beatTime,
                                                                                     dynamic: dynamic,
                                                                                     kind: .step))

        context.lastDirectionDynamic = dynamic
    }

    // A chord tone's own `dynamics` is recorded exactly like its lead note's
    // — both are individually written `<note>` elements, each free to carry
    // (or omit) the attribute.
    private static func _recordDynamic(_ note: MXLNote,
                                       attack: BeatTime,
                                       voiceID: String?,
                                       _ context: inout MusicXML.Importer.Context) {
        guard let dynamic = convertToDynamic(note)
        else { return }

        context.noteDynamicEvents[voiceID, default: []].append((beatTime: attack, dynamic: dynamic))
    }

    private static func _scorePartsByID(_ score: MusicXML.Score) -> [String: MXLScorePart] {
        var result: [String: MXLScorePart] = [:]

        for item in score.partList.items {
            if case let .scorePart(scorePart) = item {
                result[scorePart.id] = scorePart
            }
        }

        return result
    }

    // One step along `dynamicScale` in the given wedge kind's direction,
    // clamped at either end — a wedge beyond `ffff` stays `ffff`, one
    // beyond `pppp` stays `pppp`, rather than producing no shift at all.
    // `kind` is always `.crescendo` or `.diminuendo` in practice: those are
    // the only cases `_handleWedge` ever stores in `pendingWedges`.
    private static func _shifted(_ dynamic: Dynamic,
                                 kind: MXLWedge.Kind) -> Dynamic {
        guard let index = dynamicScale.firstIndex(of: dynamic)
        else { return dynamic }

        let shift = kind == .crescendo ? 1 : -1
        let clampedIndex = min(max(index + shift, 0), dynamicScale.count - 1)

        return dynamicScale[clampedIndex]
    }

    // MusicXML declares no voice order anywhere — a `<voice>` id is a
    // free-form string a note simply carries, with nothing in the
    // `<part-list>` preamble (or anywhere else) enumerating a part's voices
    // — so `context.voiceIDs` only ever reflects the order each id was
    // first met while walking notes, which need not be ascending (a
    // higher-numbered voice's first note routinely precedes a
    // lower-numbered voice's in the raw file). Sorting here, once voice
    // resolution is otherwise done, gives every consumer the reading order
    // a listener actually expects (1, 2, 3, …) instead of encounter order.
    private static func _voices(from context: MusicXML.Importer.Context) -> [MusicXML.Voice] {
        context.voiceIDs.sorted { _voiceSortKey($0) < _voiceSortKey($1) }.map { id in
            MusicXML.Voice(id: id,
                           noteDynamicEvents: context.noteDynamicEvents[id] ?? [],
                           noteTable: context.noteTables[id] ?? NoteTable())
        }
    }

    // Numeric ids sort by their integer value; a non-numeric or absent
    // (`nil`, the implicit voice) id sorts after every numeric one,
    // ordered lexicographically among themselves.
    private static func _voiceSortKey(_ id: String?) -> (Int, String) {
        guard let id, let number = Int(id)
        else { return (Int.max, id ?? "") }

        return (number, id)
    }

    // MARK: Private Instance Methods

    // Folds a chord tone into the pitch table using its lead note's onset and
    // duration, or inserts (or defers, via `pendingTies`) a standalone note
    // or the lead note of a new chord.
    private func _insert(_ pitch: IvorTuning.Pitch,
                         attack: BeatTime,
                         duration: BeatDuration,
                         tie: [MXLTie],
                         voiceID: String?,
                         _ context: inout MusicXML.Importer.Context) {
        let hasStart = tie.contains { $0.kind == .start }
        let hasStop = tie.contains { $0.kind == .stop }

        if hasStop,
           var pending = context.pendingTies[voiceID]?[pitch] {
            pending.duration += duration

            if hasStart {
                context.pendingTies[voiceID, default: [:]][pitch] = pending
            } else {
                var table = context.noteTable(forVoice: voiceID)

                table.insert(attack: pending.attack,
                             duration: pending.duration,
                             pitch: pitch)

                context.noteTables[voiceID] = table
                context.pendingTies[voiceID]?[pitch] = nil
            }

            return
        }

        _ = context.noteTable(forVoice: voiceID)  // registers the voice even when deferred or folded

        if hasStart {
            context.pendingTies[voiceID, default: [:]][pitch] = (attack, duration)

            return
        }

        var table = context.noteTables[voiceID] ?? NoteTable()

        table.insert(attack: attack,
                     duration: duration,
                     pitch: pitch)

        context.noteTables[voiceID] = table
    }

    private func _resolve(_ item: MXLMusicItem,
                          measureNumber: String,
                          _ context: inout MusicXML.Importer.Context) throws(MusicXML.Error) {
        switch item {
        case let .attributes(attributes):
            Self._apply(attributes, to: &context)

        case let .backup(backup):
            let duration = try rhythm.resolve(count: backup.duration.intValue,
                                              activeDivisions: context.activeDivisions,
                                              context: "backup in measure \(measureNumber)")

            guard let rewound = MusicXML.Duration.subtracting(context.cursor, duration)
            else { throw MusicXML.Error.unbalancedBackup("measure \(measureNumber)") }

            context.cursor = rewound

        case .barline,
             .bookmark,
             .figuredBass,
             .grouping,
             .harmony,
             .link,
             .listening,
             .print:
            break

        case let .direction(direction):
            let beatTime = convertToBeatTime(context.measureStart + context.cursor)

            if let sound = direction.sound,
               let pan = convertToPan(sound) {
                context.panEvents.append((beatTime: beatTime, pan: pan))
            }

            // A `<sound>`'s own `tempo` — a MIDI-style playback hint — takes
            // priority over this same direction's visual-only `<metronome>`
            // mark, the same precedence its `dynamics` attribute gets over a
            // notated dynamics mark below.
            if let tempo = direction.sound.flatMap(convertToTempo) ?? extractMetronome(direction).flatMap(convertToTempo) {
                context.tempoEvents.append((beatTime: beatTime, tempo: tempo))
            }

            // A `<sound>`'s own `dynamics` — a MIDI-style playback hint,
            // like the note-level `dynamics` voices are preferred by
            // elsewhere — takes priority over this same direction's
            // visual-only `<dynamics>` mark.
            if let dynamic = direction.sound.flatMap(convertToDynamic) ?? convertToDynamic(direction) {
                Self._recordDirectionDynamic(dynamic, at: beatTime, &context)
            }

            if let wedge = extractWedge(direction) {
                Self._handleWedge(wedge, at: beatTime, &context)
            }

        case let .forward(forward):
            let duration = try rhythm.resolve(count: forward.duration.intValue,
                                              activeDivisions: context.activeDivisions,
                                              context: "forward in measure \(measureNumber)")

            _ = context.noteTable(forVoice: forward.voice?.voice)  // registers the voice
            context.advance(duration)

        case let .note(note):
            try _resolve(note, measureNumber: measureNumber, &context)

        case let .sound(sound):
            let beatTime = convertToBeatTime(context.measureStart + context.cursor)

            if let tempo = convertToTempo(sound) {
                context.tempoEvents.append((beatTime: beatTime, tempo: tempo))
            }

            if let pan = convertToPan(sound) {
                context.panEvents.append((beatTime: beatTime, pan: pan))
            }

            if let dynamic = convertToDynamic(sound) {
                Self._recordDirectionDynamic(dynamic, at: beatTime, &context)
            }
        }
    }

    // Grace notes (`.graceNote`/`.graceNoteCue`) and cue notes
    // (`.graceNoteCue`/`.regularNoteCue`) are dropped from the note table
    // entirely, matching how `ABC.Importer.Walker` and
    // `Guido.Importer.Walker` both already treat their own formats'
    // ornament/grace constructs — never inserting a table entry for them at
    // all — rather than inventing a MusicXML-only exception. A grace note
    // carries no notated duration of its own (there is nothing to give it
    // but an invalid, musically meaningless zero), and a cue note is a
    // visual reference to another part's material that isn't meant to sound
    // here either. `context.advance(duration)` still runs for a dropped cue
    // note (a real, nonzero notated duration) so later notes on the same
    // voice keep their correct position; a dropped grace note's `.zero`
    // duration makes that a no-op anyway.
    private func _resolve(_ note: MXLNote,
                          measureNumber: String,
                          _ context: inout MusicXML.Importer.Context) throws(MusicXML.Error) {
        let fullNote: MXLFullNote
        let duration: MusicXML.Duration
        let tie: [MXLTie]
        let isDropped: Bool

        switch note.content {
        case let .graceNote(content, _, noteTie):
            fullNote = content
            duration = .zero
            tie = noteTie
            isDropped = true

        case let .graceNoteCue(content, _):
            fullNote = content
            duration = .zero
            tie = []
            isDropped = true

        case let .regularNote(content, count, noteTie):
            fullNote = content
            duration = try rhythm.resolve(count: count.intValue,
                                          activeDivisions: context.activeDivisions,
                                          context: "note in measure \(measureNumber)")
            tie = noteTie
            isDropped = false

        case let .regularNoteCue(content, count):
            fullNote = content
            duration = try rhythm.resolve(count: count.intValue,
                                          activeDivisions: context.activeDivisions,
                                          context: "note in measure \(measureNumber)")
            tie = []
            isDropped = true
        }

        let voiceID = note.voice?.voice

        switch fullNote.content {
        case let .pitch(written):
            let sounding = try transposer.transpose(written,
                                                    by: Self._activeTranspose(for: note, in: context),
                                                    context: "note in measure \(measureNumber)")
            let pitch = try convertToStandardPitch(sounding)

            guard !fullNote.isChord
            else {
                guard !isDropped
                else {
                    _ = context.noteTable(forVoice: voiceID)  // registers the voice

                    return
                }

                let base = MusicXML.Duration.subtracting(context.cursor, context.lastDuration) ?? context.cursor
                let attack = convertToBeatTime(context.measureStart + base)

                _insert(pitch,
                        attack: attack,
                        duration: convertToBeatDuration(context.lastDuration),
                        tie: tie,
                        voiceID: voiceID,
                        &context)

                Self._recordDynamic(note, attack: attack, voiceID: voiceID, &context)

                return
            }

            if isDropped {
                _ = context.noteTable(forVoice: voiceID)  // registers the voice
            } else {
                let attack = convertToBeatTime(context.measureStart + context.cursor)

                _insert(pitch,
                        attack: attack,
                        duration: convertToBeatDuration(duration),
                        tie: tie,
                        voiceID: voiceID,
                        &context)

                Self._recordDynamic(note, attack: attack, voiceID: voiceID, &context)
            }

            context.lastDuration = duration
            context.advance(duration)

        case .rest:
            _ = context.noteTable(forVoice: voiceID)  // registers the voice
            context.lastDuration = duration
            context.advance(duration)

        case .unpitched:
            _ = context.noteTable(forVoice: voiceID)  // registers the voice

            guard !fullNote.isChord
            else { return }

            context.lastDuration = duration
            context.advance(duration)
        }
    }

    // The linear (document-order) expansion pass, once per part, followed by
    // the play-order cursor walk over the `Plan`'s measure indices — see
    // `Expansion`'s type-level comment for why these are two passes rather
    // than one.
    private func _walk(_ part: MXLScorePartwise.Part,
                       order: [Int]) throws(MusicXML.Error) -> MusicXML.Importer.Context {
        var expansion = MusicXML.Importer.Walker.Expansion()
        let plans = part.measures.enumerated().map { index, measure in
            expansion.plan(measure, at: index, in: part)
        }

        var context = MusicXML.Importer.Context()

        for index in order where index < part.measures.count {
            let measure = part.measures[index]

            context.cursor = .zero
            context.lastDuration = .zero
            context.measureAdvance = .zero

            switch plans[index] {
            case let .items(items):
                for item in items {
                    try _resolve(item, measureNumber: measure.number, &context)
                }

            case .syntheticRest:
                let time = context.times[nil] ?? context.times.values.first
                let duration = try rhythm.wholeMeasureDuration(from: time,
                                                               context: "multiple-rest in measure \(measure.number)")

                context.advance(duration)
            }

            context.measureStart += context.measureAdvance
        }

        Self._flushPendingTies(&context)

        return context
    }
}
