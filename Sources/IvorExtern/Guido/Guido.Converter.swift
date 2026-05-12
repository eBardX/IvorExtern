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
            return try Self._convertToWork(score)
        } catch let error as any EnhancedError {
            throw Guido.Error.convertFailure(error)
        }
    }

    // MARK: Private Type Methods

    private static func _convertGuidoChord(_ chord: Guido.Chord,
                                           _ context: inout Self.Context) throws {
        guard !context.inChord
        else { throw Guido.Error.nestedChord }

        context.beginChord()

        for segment in chord.segments {
            try _convertGuidoSymbols(segment.symbols, &context)
        }

        context.endChord()
    }

    private static func _convertGuidoNote(_ note: Guido.Note,
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

    private static func _convertGuidoRest(_ rest: Guido.Rest,
                                          _ context: inout Self.Context) throws {
        let bdur = try convertToBeatDuration(rest.duration)

        context.advance(bdur)
    }

    private static func _convertGuidoSymbol(_ symbol: Guido.Symbol,
                                            _ context: inout Self.Context) throws {
        switch symbol {
        case let .chord(chord):
            try _convertGuidoChord(chord, &context)

        case let .note(note):
            try _convertGuidoNote(note, &context)

        case let .rest(rest):
            try _convertGuidoRest(rest, &context)

        case .tablature:
            throw Guido.Error.unsupportedSymbol(symbol)

        case let .tag(tag):
            try _convertGuidoTag(tag, &context)

        case .variable:
            throw Guido.Error.unsupportedSymbol(symbol)
        }
    }

    private static func _convertGuidoSymbols(_ symbols: [Guido.Symbol],
                                             _ context: inout Self.Context) throws {
        for symbol in symbols {
            try _convertGuidoSymbol(symbol, &context)
        }
    }

    private static func _convertGuidoTag(_ tag: Guido.Tag,
                                         _ context: inout Self.Context) throws {
        guard !tag.symbols.isEmpty
        else { return }

        try _convertGuidoSymbols(tag.symbols, &context)
    }

    private static func _convertGuidoVoice(_ voice: Guido.Voice,
                                           _ context: inout Self.Context) throws {
        try _convertGuidoSymbols(voice.symbols, &context)
    }

    private static func _convertToPart(_ voice: Guido.Voice) throws -> Part<BeatTime, Pitch> {
        var context = Self.Context()

        try _convertGuidoVoice(voice, &context)

        return Part(name: determinePartName(voice),
                    noteTable: context.noteTable)
    }

    private static func _convertToParts(_ voices: [Guido.Voice]) throws -> [Part<BeatTime, Pitch>] {
        try voices.map { try _convertToPart($0) }
    }

    private static func _convertToWork(_ score: Guido.Score) throws -> Work {
        try Work(name: determineWorkName(score),
                 content: .standardBeat(_convertToParts(score.voices),
                                        TempoMap()))
    }
}

// MARK: - Sendable

extension Guido.Converter: Sendable {
}
