// © 2026 John Gary Pusey (see LICENSE.md)

internal import Foundation
internal import IvorGuido
internal import IvorModel
internal import IvorTiming

private import XestiNumbers

// One pass per voice over its `GMNSymbol`s, walking the note/chord/rest
// cases directly against the AST: duration resolution (sticky base,
// non-sticky dots) and pitch resolution (sticky octave, context-free
// accidental) inline, `$variable` reference splicing
// inline with a cycle guard (`_expandVariable`/`_expandedSymbols`), and tied
// notes/chords coalesced into a single table entry via `Context`'s
// `pendingNote`/`tieArmed` slots rather than as a separate post-pass over an
// intermediate event stream. Grace notes, tablature attachments, and the
// generic tag-passthrough lane remain out of scope — every tag other than
// `\tie`, `\tempo`, `\intensity`, and `\crescendo`/`\diminuendo` is inert
// here, contributing nothing beyond closing out whatever note/chord it
// interrupts.
//
// `$variable` expansion has no access to `GMNVariable`'s declaration-time
// symbol stash (an `internal` property of `IvorGuido`, invisible outside
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

    internal func walk(_ voice: Guido.Voice) throws(Guido.Error) -> Guido.Importer.Context {
        var context = Guido.Importer.Context()
        var inProgressVariableNames: Set<GMNVariable.Name> = []

        try _walk(voice.symbols, &context, &inProgressVariableNames)
        try Self._flushPendingNote(&context)

        return context
    }

    // MARK: Private Instance Methods

    private func _expandedSymbols(_ name: GMNVariable.Name) -> [GMNSymbol] {
        guard case let .string(text)? = variables[name]?.value,
              let (score, _) = try? Guido.BaseParser().parse(Data("\(declarationsText) [ \(text) ]".utf8)),
              let voice = score.voices.first
        else { return [] }

        return voice.symbols
    }

    private func _expandVariable(_ name: GMNVariable.Name,
                                 _ context: inout Guido.Importer.Context,
                                 _ inProgressVariableNames: inout Set<GMNVariable.Name>) throws(Guido.Error) {
        guard !inProgressVariableNames.contains(name)
        else { throw Guido.Error.circularVariableReference(name) }

        inProgressVariableNames.insert(name)

        defer { inProgressVariableNames.remove(name) }

        try _walk(_expandedSymbols(name), &context, &inProgressVariableNames)
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
        case .whole:
            let startBeatTime = context.currentBeatTime
            let startDynamic = context.lastDynamic

            try _walk(ramp.body, &context, &inProgressVariableNames)

            Self._closeDynamicRamp(direction: ramp.direction,
                                   startBeatTime: startBeatTime,
                                   startDynamic: startDynamic,
                                   endBeatTime: context.currentBeatTime,
                                   &context)

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
        case let .dynamicRamp(ramp):
            try Self._flushPendingNote(&context)

            context.tieArmed = false

            try _handleDynamicRamp(ramp, &context, &inProgressVariableNames)

        case let .instrument(instrument):
            try Self._flushPendingNote(&context)

            context.tieArmed = false

            context.instrumentEvents.append((beatTime: context.currentBeatTime, instrument: convertToInstrument(instrument)))

        case let .intensity(intensity):
            try Self._flushPendingNote(&context)

            context.tieArmed = false

            Self._handleIntensity(intensity, &context)

        case let .tempo(tempo):
            try Self._flushPendingNote(&context)

            context.tieArmed = false

            if let metronome = tempo.metronome,
               let tempoValue = convertToTempo(metronome) {
                context.tempoEvents.append((beatTime: context.currentBeatTime, tempo: tempoValue))
            }

        case let .tie(tie) where tie.span == .end:
            context.tieArmed = true

        default:
            try Self._flushPendingNote(&context)

            context.tieArmed = false
        }
    }

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

// MARK: -

extension Guido.Importer.Walker {

    // MARK: Private Type Properties

    // The ten standard dynamic levels `convertToDynamic(_:)` recognizes, in
    // rising order, so a ramp's one-step shift can locate its starting level
    // and move to its neighbor.
    private static let dynamicScale: [Dynamic] = [.pppp, .ppp, .pp, .p, .mp, .mf, .f, .ff, .fff, .ffff]

    // MARK: Private Type Methods

    private static func _applyDots(_ base: Guido.Duration,
                                   _ count: GMNDuration.DotCount?) -> Guido.Duration {
        guard let count
        else { return base }

        var addend = base.numberValue
        var total = base.numberValue

        for _ in 0..<count.uintValue {
            addend *= Number(numerator: 1, denominator: 2)
            total += addend
        }

        return Guido.Duration(numberValue: total)
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

    private static func _considerTie(_ notes: [Guido.Note],
                                     _ attackTime: BeatTime,
                                     _ context: inout Guido.Importer.Context) throws(Guido.Error) {
        if context.tieArmed,
           let pending = context.pendingNote,
           _pitchesMatch(pending.notes, notes) {
            context.pendingNote = (attackTime: pending.attackTime,
                                   notes: zip(pending.notes, notes).map {
                                       Guido.Note(duration: Guido.Duration(numberValue: $0.duration.numberValue + $1.duration.numberValue),
                                                  pitch: $0.pitch)
                                   })
        } else {
            try _flushPendingNote(&context)
            context.pendingNote = (attackTime: attackTime, notes: notes)
        }

        context.tieArmed = false
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

    private static func _flushPendingNote(_ context: inout Guido.Importer.Context) throws(Guido.Error) {
        guard let pending = context.pendingNote
        else { return }

        for note in pending.notes where note.pitch.name != .empty {
            let pit = try convertToStandardPitch(note.pitch)

            context.noteTable.insert(attack: pending.attackTime,
                                     duration: convertToBeatDuration(note.duration),
                                     pitch: pit)
        }

        context.pendingNote = nil
    }

    private static func _handleChord(_ chord: GMNChord,
                                     _ context: inout Guido.Importer.Context) throws(Guido.Error) {
        let attackTime = context.currentBeatTime
        let resolved = try Guido.Chord(notes: _resolveChordMembers(chord, &context))
        let maxDuration = resolved.notes.map { convertToBeatDuration($0.duration) }.max() ?? .zero

        try _considerTie(resolved.notes, attackTime, &context)

        context.advance(maxDuration)
    }

    private static func _handleIntensity(_ intensity: GMNIntensity,
                                         _ context: inout Guido.Importer.Context) {
        guard let dynamic = convertToDynamic(intensity.type)
        else { return }

        context.dynamicEvents.append(Guido.Importer.Context.DynamicEvent(beatTime: context.currentBeatTime,
                                                                         dynamic: dynamic,
                                                                         kind: .step))

        context.lastDynamic = dynamic
    }

    private static func _handleNote(_ note: GMNNote,
                                    _ context: inout Guido.Importer.Context) throws(Guido.Error) {
        let attackTime = context.currentBeatTime
        let resolved = try _resolveNote(note, &context)
        let bdur = convertToBeatDuration(resolved.duration)

        try _considerTie([resolved], attackTime, &context)

        context.advance(bdur)
    }

    private static func _handleRest(_ rest: GMNRest,
                                    _ context: inout Guido.Importer.Context) throws(Guido.Error) {
        let resolved = try Guido.Rest(duration: _resolveRestDuration(rest, &context))

        try _flushPendingNote(&context)

        context.tieArmed = false
        context.advance(convertToBeatDuration(resolved.duration))
    }

    private static func _pitchesMatch(_ lhs: [Guido.Note],
                                      _ rhs: [Guido.Note]) -> Bool {
        lhs.count == rhs.count && zip(lhs, rhs).allSatisfy { $0.pitch == $1.pitch }
    }

    private static func _resolveBase(_ duration: GMNDuration?,
                                     _ context: inout Guido.Importer.Context) throws(Guido.Error) -> Guido.Duration {
        guard let duration
        else { return context.lastDuration }

        if let milliseconds = duration.milliseconds {
            throw Guido.Error.unrepresentableDuration("\(milliseconds)ms")
        }

        guard let numerator = duration.numerator,
              let denominator = duration.denominator
        else { return context.lastDuration }

        let resolved = Guido.Duration(numberValue: Number(numerator: numerator,
                                                          denominator: denominator))

        context.lastDuration = resolved

        return resolved
    }

    private static func _resolveChordMembers(_ chord: GMNChord,
                                             _ context: inout Guido.Importer.Context) throws(Guido.Error) -> [Guido.Note] {
        var notes: [Guido.Note] = []

        for segment in chord.segments {
            if let note = try _resolveChordSegmentNote(segment.symbols, &context) {
                notes.append(note)
            }
        }

        return notes
    }

    // Threads sticky duration/octave state through a segment's symbols and
    // returns the segment's own note, if it has one — matching the
    // parser-level invariant that a segment carries at most one music
    // symbol. A tag or `$variable` reference nested inside a chord segment
    // is out of scope (see the type-level comment) and so is simply
    // skipped, along with a tablature symbol.
    private static func _resolveChordSegmentNote(_ symbols: [GMNSymbol],
                                                 _ context: inout Guido.Importer.Context) throws(Guido.Error) -> Guido.Note? {
        var result: Guido.Note?

        for symbol in symbols {
            switch symbol {
            case let .note(note):
                result = try _resolveNote(note, &context)

            case let .rest(rest):
                _ = try _resolveRestDuration(rest, &context)

            default:
                break
            }
        }

        return result
    }

    private static func _resolvedAccidental(_ accidental: GMNPitch.Accidental) -> Guido.Pitch.Accidental {
        switch accidental {
        case .doubleFlat:
            .doubleFlat

        case .doubleSharp:
            .doubleSharp

        case .flat:
            .flat

        case .impliedSharp,
             .sharp:
            .sharp

        case .omitted:
            .natural
        }
    }

    private static func _resolvedName(_ name: GMNPitch.Name) -> Guido.Pitch.Name {
        switch name {
        case .a,
             .ais,
             .la:
            .a

        case .b,
             .h,
             .si,
             .ti:
            .b

        case .c,
             .cis,
             .do:
            .c

        case .d,
             .dis,
             .re:
            .d

        case .e,
             .mi:
            .e

        case .empty:
            .empty

        case .f,
             .fa,
             .fis:
            .f

        case .g,
             .gis,
             .sol:
            .g
        }
    }

    private static func _resolveDuration(_ duration: GMNDuration?,
                                         _ context: inout Guido.Importer.Context) throws(Guido.Error) -> Guido.Duration {
        let base = try _resolveBase(duration, &context)

        return _applyDots(base, duration?.dots)
    }

    private static func _resolveNote(_ note: GMNNote,
                                     _ context: inout Guido.Importer.Context) throws(Guido.Error) -> Guido.Note {
        let pitch = _resolvePitch(note.pitch, &context)
        let duration = try _resolveDuration(note.duration, &context)

        return Guido.Note(duration: duration, pitch: pitch)
    }

    private static func _resolvePitch(_ pitch: GMNPitch,
                                      _ context: inout Guido.Importer.Context) -> Guido.Pitch {
        let octave: GMNPitch.Octave

        if let written = pitch.octave {
            octave = written
            context.lastOctave = written
        } else {
            octave = context.lastOctave
        }

        return Guido.Pitch(accidental: _resolvedAccidental(pitch.accidental),
                           name: _resolvedName(pitch.name),
                           octave: octave)
    }

    private static func _resolveRestDuration(_ rest: GMNRest,
                                             _ context: inout Guido.Importer.Context) throws(Guido.Error) -> Guido.Duration {
        try _resolveDuration(rest.duration, &context)
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
}
