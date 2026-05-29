// © 2025–2026 John Gary Pusey (see LICENSE.md)

internal import IvorModel

private import IvorABC
private import IvorTiming
private import IvorTuning
private import XestiTools

extension ABC {

    // MARK: Internal Nested Types

    internal struct Converter {
    }
}

// MARK: -

extension ABC.Converter {

    // MARK: Internal Instance Methods

    internal func convert(_ tunebook: ABC.Tunebook) throws -> [Work] {
        do {
            return try Self._convert(tunebook: tunebook)
        } catch let error as any EnhancedError {
            throw ABC.Error.convertFailure(error)
        }
    }

    // MARK: Private Type Methods

    private static func _convert(tune: ABC.Tune) throws -> Part<BeatTime, Pitch> {
        var context = Self.Context()

        try _update(tune.entries, &context)

        return Part(name: "",                       // for now…
                    noteTable: context.noteTable)
    }

    private static func _convert(tune: ABC.Tune,
                                 headers: [ABC.Header]) throws -> Work {
        try Work(name: determineWorkName(tune),
                 content: .standardBeat(_convert(tune: tune,
                                                 voices: determineVoices(tune),
                                                 headers: headers),
                                        TempoMap()))
    }

    private static func _convert(tune: ABC.Tune,
                                 voice: ABC.Voice) throws -> Part<BeatTime, Pitch> {
        let filteredEntries = try filterEntries(voice, tune)

        var context = Self.Context()

        try _update(filteredEntries, &context)

        return Part(name: voice.name ?? voice.subname ?? voice.id,
                    noteTable: context.noteTable)
    }

    private static func _convert(tune: ABC.Tune,
                                 voices: [ABC.Voice],
                                 headers: [ABC.Header]) throws -> [Part<BeatTime, Pitch>] {
        if voices.isEmpty {
            return try [_convert(tune: tune)]
        }

        return try voices.map {
            try _convert(tune: tune,
                         voice: $0)
        }
    }

    private static func _convert(tunebook: ABC.Tunebook) throws -> [Work] {
        try tunebook.tunes.map {
            try _convert(tune: $0,
                         headers: tunebook.headers)
        }
    }

    private static func _update(_ chord: [ABC.Note],
                                _ context: inout Self.Context) throws {
        var cdur: BeatDuration = .zero

        for note in chord {
            let bdur = try convertToBeatDuration(note.duration)
            let pit = try convertToStandardPitch(note.pitch)

            context.noteTable.insert(attack: context.currentBeatTime,
                                     duration: bdur,
                                     pitch: pit)

            if cdur < bdur {
                cdur = bdur
            }
        }

        context.advance(cdur)
    }

    private static func _update(_ entries: [ABC.Entry],
                                _ context: inout Self.Context) throws {
        for entry in entries {
            switch entry {
            case let .symbols(symbols):
                try _update(symbols, &context)

            default:
                break
            }
        }
    }

    private static func _update(_ note: ABC.Note,
                                _ context: inout Self.Context) throws {
        let bdur = try convertToBeatDuration(note.duration)
        let pit = try convertToStandardPitch(note.pitch)

        context.noteTable.insert(attack: context.currentBeatTime,
                                 duration: bdur,
                                 pitch: pit)

        context.advance(bdur)
    }

    private static func _update(_ rest: ABC.Rest,
                                _ context: inout Self.Context) throws {
        switch rest {
        case .multiMeasure: // ignore for now… need to know current length of measure
            break

        case let .regular(_, duration):
            let bdur = try convertToBeatDuration(duration)

            context.advance(bdur)
        }
    }

    private static func _update(_ symbols: [ABC.Symbol],
                                _ context: inout Self.Context) throws {
        for symbol in symbols {
            switch symbol {
            case .brokenRhythm: // ignore for now…
                break

            case let .chord(chord):
                try _update(chord, &context)

            case .graceNotes:   // ignore for now…
                break

            case let .note(note):
                try _update(note, &context)

            case let .rest(rest):
                try _update(rest, &context)

            case .tuplet:       // ignore for now…
                break

            default:
                break
            }
        }
    }
}

// MARK: - Sendable

extension ABC.Converter: Sendable {
}
