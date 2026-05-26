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
        var works: [Work] = []

        do {
            for tune in tunebook.tunes {
                // initialize ABC.Convert.Context from tunebook.headers (each iteration of loop) ???

                try works.append(Self._convertToWork(tune, tunebook.headers))
            }
        } catch let error as any EnhancedError {
            throw ABC.Error.convertFailure(error)
        }

        return works
    }

    // MARK: Private Type Methods

    private static func _convertABCChord(_ chord: [ABC.Note],
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

    private static func _convertABCEntries(_ entries: [ABC.Entry],
                                           _ context: inout Self.Context) throws {
        for entry in entries {
            switch entry {
            case let .symbols(symbols):
                try _convertABCSymbols(symbols, &context)

            default:
                break
            }
        }
    }

    private static func _convertABCNote(_ note: ABC.Note,
                                        _ context: inout Self.Context) throws {
        let bdur = try convertToBeatDuration(note.duration)
        let pit = try convertToStandardPitch(note.pitch)

        context.noteTable.insert(attack: context.currentBeatTime,
                                 duration: bdur,
                                 pitch: pit)

        context.advance(bdur)
    }

    private static func _convertABCRest(_ rest: ABC.Rest,
                                        _ context: inout Self.Context) throws {
        switch rest {
        case .multiMeasure: // ignore for now… need to know current length of measure
            break

        case let .regular(_, duration):
            let bdur = try convertToBeatDuration(duration)

            context.advance(bdur)
        }
    }

    private static func _convertABCSymbols(_ symbols: [ABC.Symbol],
                                           _ context: inout Self.Context) throws {
        for symbol in symbols {
            switch symbol {
            case .brokenRhythm: // ignore for now…
                break

            case let .chord(chord):
                try _convertABCChord(chord, &context)

            case .graceNotes:   // ignore for now…
                break

            case let .note(note):
                try _convertABCNote(note, &context)

            case let .rest(rest):
                try _convertABCRest(rest, &context)

            case .tuplet:       // ignore for now…
                break

            default:
                break
            }
        }
    }

    private static func _convertToPart(_ tune: ABC.Tune) throws -> Part<BeatTime, Pitch> {
        var context = Self.Context()

        try _convertABCEntries(tune.entries, &context)

        return Part(name: "",                       // for now…
                    noteTable: context.noteTable)
    }

    private static func _convertToPart(_ tune: ABC.Tune,
                                       _ voice: ABC.Voice) throws -> Part<BeatTime, Pitch> {
        let filteredEntries = try filterEntries(voice, tune)

        var context = Self.Context()

        try _convertABCEntries(filteredEntries, &context)

        return Part(name: voice.name ?? voice.subname ?? voice.id,
                    noteTable: context.noteTable)
    }

    private static func _convertToParts(_ tune: ABC.Tune,
                                        _ headers: [ABC.Header]) throws -> [Part<BeatTime, Pitch>] {
        let voices = determineVoices(tune)

        if voices.isEmpty {
            return try [_convertToPart(tune)]
        }

        return try voices.map { try _convertToPart(tune, $0) }
    }

    private static func _convertToWork(_ tune: ABC.Tune,
                                       _ headers: [ABC.Header]) throws -> Work {
        try Work(name: determineWorkName(tune),
                 content: .standardBeat(_convertToParts(tune, headers),
                                        TempoMap()))
    }
}

// MARK: - Sendable

extension ABC.Converter: Sendable {
}
