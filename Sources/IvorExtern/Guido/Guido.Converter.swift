// © 2025–2026 John Gary Pusey (see LICENSE.md)

internal import IvorModel

private import IvorGuido
private import IvorTiming
private import IvorTuning
private import XestiTools

extension Guido {

    // MARK: Internal Instance Methods

    internal struct Converter {
    }
}

// MARK: -

extension Guido.Converter {

    // MARK: Internal Instance Methods

    internal func convert(_ score: Guido.Score) throws -> Work {
        do {
            return try Self._convert(score: score)
        } catch let error as any EnhancedError {
            throw Guido.Error.convertFailure(error)
        }
    }

    // MARK: Private Type Methods

    private static func _convert(score: Guido.Score) throws -> Work {
        try Work(name: determineWorkName(score),
                 content: .standardBeat(_convert(voices: score.voices),
                                        TempoMap()))
    }

    private static func _convert(voice: Guido.Voice) throws -> Part<BeatTime, Pitch> {
        var context = Self.Context()

        try _update(voice, &context)

        return Part(name: determinePartName(voice),
                    noteTable: context.noteTable)
    }

    private static func _convert(voices: [Guido.Voice]) throws -> [Part<BeatTime, Pitch>] {
        try voices.map { try _convert(voice: $0) }
    }

    private static func _update(_ chord: Guido.Chord,
                                _ context: inout Self.Context) throws {
        guard !context.inChord
        else { throw Guido.Error.nestedChord }

        context.beginChord()

        for segment in chord.segments {
            try _update(segment.symbols, &context)
        }

        context.endChord()
    }

    private static func _update(_ note: Guido.Note,
                                _ context: inout Self.Context) throws {
        let bdur = try convertToBeatDuration(note.duration)

        if note.pitch.name != .empty {
            let pit = try convertToStandardPitch(note.pitch)

            context.noteTable.insert(attack: context.currentBeatTime,
                                     duration: bdur,
                                     pitch: pit)
        }

        context.advance(bdur)
    }

    private static func _update(_ rest: Guido.Rest,
                                _ context: inout Self.Context) throws {
        let bdur = try convertToBeatDuration(rest.duration)

        context.advance(bdur)
    }

    private static func _update(_ symbol: Guido.Symbol,
                                _ context: inout Self.Context) throws {
        switch symbol {
        case let .chord(chord):
            try _update(chord, &context)

        case let .note(note):
            try _update(note, &context)

        case let .rest(rest):
            try _update(rest, &context)

        case .tablature:
            throw Guido.Error.unsupportedSymbol(symbol)

        case let .tag(tag):
            try _update(tag, &context)

        case .variable:
            throw Guido.Error.unsupportedSymbol(symbol)
        }
    }

    private static func _update(_ symbols: [Guido.Symbol],
                                _ context: inout Self.Context) throws {
        for symbol in symbols {
            try _update(symbol, &context)
        }
    }

    private static func _update(_ tag: Guido.Tag,
                                _ context: inout Self.Context) throws {
        guard !tag.symbols.isEmpty
        else { return }

        try _update(tag.symbols, &context)
    }

    private static func _update(_ voice: Guido.Voice,
                                _ context: inout Self.Context) throws {
        try _update(voice.symbols, &context)
    }
}

// MARK: - Sendable

extension Guido.Converter: Sendable {
}
