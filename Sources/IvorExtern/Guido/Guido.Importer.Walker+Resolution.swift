// © 2026 John Gary Pusey (see LICENSE.md)

internal import IvorGMN

private import XestiNumbers

// Resolving a note's pitch and duration as the walk meets it: the duration
// is sticky (a note without one takes the last one written) while dots are
// not, and the octave is sticky while the accidental is context-free. Grace
// notes resolve the same way, so they set the sticky state for the notes
// after them, as in guidolib.
extension Guido.Importer.Walker {

    // MARK: Internal Type Methods

    // The chord's notes, each with whether its segment holds a `\tieBegin`,
    // tying that tone alone to whatever follows (guidolib's
    // `{ \tieBegin:1 c, e }`).
    internal static func resolveChordMembers(_ chord: GMNChord,
                                             _ context: inout Guido.Importer.Context) throws(Guido.Error) -> [(note: Guido.Note, isTied: Bool)] {
        var members: [(note: Guido.Note, isTied: Bool)] = []

        for segment in chord.segments {
            if let member = try _resolveChordSegmentNote(segment.symbols, &context) {
                members.append(member)
            }
        }

        return members
    }

    internal static func resolvedAccidental(_ accidental: GMNPitch.Accidental) -> Guido.Pitch.Accidental {
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

    internal static func resolvedName(_ name: GMNPitch.Name) -> Guido.Pitch.Name {
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

    internal static func resolveNote(_ note: GMNNote,
                                     _ context: inout Guido.Importer.Context) throws(Guido.Error) -> Guido.Note {
        let pitch = _resolvePitch(note.pitch, &context)
        let duration = try _resolveDuration(note.duration, &context)

        return Guido.Note(duration: duration, pitch: pitch)
    }

    internal static func resolveRestDuration(_ rest: GMNRest,
                                             _ context: inout Guido.Importer.Context) throws(Guido.Error) -> Guido.Duration {
        try _resolveDuration(rest.duration, &context)
    }

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

    // Threads sticky duration/octave state through a segment's symbols and
    // returns the segment's own note, if it has one — matching the
    // parser-level invariant that a segment carries at most one music
    // symbol — and whether a `\tieBegin` ties it to whatever follows. A
    // `\tieEnd` needs no handling: the tone it closes continues by pitch
    // (see `Guido.Importer.Context.flushPendingNote()`). Any other tag or
    // `$variable` reference nested inside a chord segment is out of scope
    // (see the type-level comment) and so is simply skipped, along with a
    // tablature symbol.
    private static func _resolveChordSegmentNote(_ symbols: [GMNSymbol],
                                                 _ context: inout Guido.Importer.Context) throws(Guido.Error) -> (note: Guido.Note, isTied: Bool)? {
        var result: Guido.Note?
        var isTied = false

        for symbol in symbols {
            switch symbol {
            case let .note(note):
                result = try resolveNote(note, &context)

            case let .rest(rest):
                _ = try resolveRestDuration(rest, &context)

            case let .tag(.tie(tie)) where tie.span == .begin:
                isTied = true

            default:
                break
            }
        }

        return result.map { ($0, isTied) }
    }

    private static func _resolveDuration(_ duration: GMNDuration?,
                                         _ context: inout Guido.Importer.Context) throws(Guido.Error) -> Guido.Duration {
        let base = try _resolveBase(duration, &context)

        return _applyDots(base, duration?.dots)
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

        return Guido.Pitch(accidental: resolvedAccidental(pitch.accidental),
                           name: resolvedName(pitch.name),
                           octave: octave)
    }
}
