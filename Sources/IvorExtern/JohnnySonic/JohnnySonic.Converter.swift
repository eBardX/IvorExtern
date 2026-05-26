// © 2025–2026 John Gary Pusey (see LICENSE.md)

internal import IvorModel

private import IvorJohnnySonic
private import IvorTiming
private import IvorTuning
private import XestiNumbers
private import XestiText
private import XestiTools

extension JohnnySonic {
    internal struct Converter {
    }
}

// MARK: -

extension JohnnySonic.Converter {

    // MARK: Internal Instance Methods

    internal func convert(_ work: Work) throws -> JohnnySonic.Score {
        do {
            return try JohnnySonic.Score(entries: Self._convert(work))
        } catch let error as any EnhancedError {
            throw JohnnySonic.Error.convertFailure(error)
        }
    }

    // MARK: Private Type Methods

    private static func _convert(_ part: Part<BeatTime, Frequency>,
                                 _ index: Int) throws -> [JohnnySonic.Entry] {
        var comment = "Part #\(index)"

        if !part.name.isEmpty {
            comment += ": " + part.name
        }

        var entries: [JohnnySonic.Entry] = try _makeBoxedComment(comment)

        part.noteTable.forEach { btime, bdur, sfreq, efreq, _ in
            let startBeat = btime.doubleValue
            let duration = bdur.doubleValue
            let volume = part.dynamicMap[btime].doubleValue * 10 // ???
            let location = part.panMap[btime].doubleValue
            let startPitch = -sfreq.doubleValue
            let endPitch = -efreq.doubleValue
            let instrument = part.instrumentMap[btime].stringValue

            if duration > 0 {
                entries.append(JohnnySonic.Entry(command: .pitches,
                                                 arguments: .double(startBeat),
                                                 .double(duration),
                                                 .double(volume),
                                                 .double(location),
                                                 .double(startPitch),
                                                 .double(endPitch),
                                                 .string(instrument)))
            }
        }

        return entries
    }

    private static func _convert(_ part: Part<BeatTime, NoteNumber>,
                                 _ index: Int) throws -> [JohnnySonic.Entry] {
        var comment = "Part #\(index)"

        if !part.name.isEmpty {
            comment += ": " + part.name
        }

        var entries: [JohnnySonic.Entry] = try _makeBoxedComment(comment)

        part.noteTable.forEach { btime, bdur, snnum, ennum, _ in
            let startBeat = btime.doubleValue
            let duration = bdur.doubleValue
            let volume = part.dynamicMap[btime].doubleValue * 10 // ???
            let location = part.panMap[btime].doubleValue
            let startPitch = snnum.doubleValue
            let endPitch = ennum.doubleValue
            let instrument = part.instrumentMap[btime].stringValue

            if duration > 0 {
                entries.append(JohnnySonic.Entry(command: .pitches,
                                                 arguments: .double(startBeat),
                                                 .double(duration),
                                                 .double(volume),
                                                 .double(location),
                                                 .double(startPitch),
                                                 .double(endPitch),
                                                 .string(instrument)))
            }
        }

        return entries
    }

    private static func _convert(_ part: Part<BeatTime, Pitch>,
                                 _ index: Int) throws -> [JohnnySonic.Entry] {
        var comment = "Part #\(index)"

        if !part.name.isEmpty {
            comment += ": " + part.name
        }

        var entries: [JohnnySonic.Entry] = try _makeBoxedComment(comment)

        part.noteTable.forEach { btime, bdur, spit, epit, _ in
            let startBeat = btime.doubleValue
            let duration = bdur.doubleValue
            let volume = part.dynamicMap[btime].doubleValue * 10 // ???
            let location = part.panMap[btime].doubleValue
            let startPitch = _pitchNumber(for: spit).doubleValue
            let endPitch = _pitchNumber(for: epit).doubleValue
            let instrument = part.instrumentMap[btime].stringValue

            if duration > 0 {
                entries.append(JohnnySonic.Entry(command: .pitches,
                                                 arguments: .double(startBeat),
                                                 .double(duration),
                                                 .double(volume),
                                                 .double(location),
                                                 .double(startPitch),
                                                 .double(endPitch),
                                                 .string(instrument)))
            }
        }

        return entries
    }

    private static func _convert(_ parts: [Part<BeatTime, Frequency>]) throws -> [JohnnySonic.Entry] {
        var entries: [JohnnySonic.Entry] = []

        for (idx, part) in parts.enumerated() {
            entries += try _convert(part, idx + 1)
        }

        return entries
    }

    private static func _convert(_ parts: [Part<BeatTime, NoteNumber>]) throws -> [JohnnySonic.Entry] {
        var entries: [JohnnySonic.Entry] = []

        for (idx, part) in parts.enumerated() {
            entries += try _convert(part, idx + 1)
        }

        return entries
    }

    private static func _convert(_ parts: [Part<BeatTime, Pitch>]) throws -> [JohnnySonic.Entry] {
        var entries: [JohnnySonic.Entry] = []

        for (idx, part) in parts.enumerated() {
            entries += try _convert(part, idx + 1)
        }

        return entries
    }

    private static func _convert(_ tempoMap: TempoMap) throws -> [JohnnySonic.Entry] {
        if tempoMap.isEmpty {
            let tempo = tempoMap.defaultTempo.doubleValue

            return [JohnnySonic.Entry(command: .tempo,
                                      arguments: .double(0),
                                      .double(1),
                                      .double(tempo),
                                      .double(tempo))]
        }

        var tmpSeq: [(BeatTime, Tempo)] = []

        tempoMap.forEach { btime, tempo, _ in
            tmpSeq.append((btime, tempo))
        }

        return zip(tmpSeq.dropLast(),
                   tmpSeq.dropFirst()).compactMap { elt in
            let startBeat = elt.0.0.doubleValue
            let endBeat = elt.1.0.doubleValue
            let duration = endBeat - startBeat
            let startTempo = elt.0.1.doubleValue
            let endTempo = elt.1.1.doubleValue

            if duration > 0 {
                return JohnnySonic.Entry(command: .tempo,
                                         arguments: .double(startBeat),
                                         .double(duration),
                                         .double(startTempo),
                                         .double(endTempo))
            } else {
                return nil
            }
        }
    }

    private static func _convert(_ work: Work) throws -> [JohnnySonic.Entry] {
        var entries: [JohnnySonic.Entry] = try _makeHeader(work)

        if let tempoMap = work.content.tempoMap {
            entries += try _convert(tempoMap)
        }

        switch work.content {
        case let .absoluteBeat(parts, _):
            entries += try _convert(parts)

        case let .keyboardBeat(parts, _):
            entries += try _convert(parts)

        case let .standardBeat(parts, _):
            entries += try _convert(parts)

        default:
            throw JohnnySonic.Error.unsupportedWorkTimeBasis(work.content.timeBasis.description)
        }

        entries += try _makeTrailer(work)

        return entries
    }

    private static func _makeBoxedComment(_ comment: String) throws -> [JohnnySonic.Entry] {
        var entries: [JohnnySonic.Entry] = []

        let line = "+-" + "-".repeating(to: comment.count) + "-+"

        entries.append(JohnnySonic.Entry(command: .comment,
                                         arguments: .string(line)))
        entries.append(JohnnySonic.Entry(command: .comment,
                                         arguments: .string("| " + comment + " |")))
        entries.append(JohnnySonic.Entry(command: .comment,
                                         arguments: .string(line)))

        return entries
    }

    private static func _makeHeader(_ work: Work) throws -> [JohnnySonic.Entry] {
        var comment = "Work"

        if !work.name.isEmpty {
            comment += ": " + work.name
        }

        return try _makeBoxedComment(comment)
    }

    private static func _makeTrailer(_ work: Work) throws -> [JohnnySonic.Entry] {
        var entries: [JohnnySonic.Entry] = [JohnnySonic.Entry(command: .comment)]

        let startBeat: Double
        let endBeat: Double

        if let timeRange = work.content.beatTimeRange {
            startBeat = timeRange.lowerBound.doubleValue
            endBeat = timeRange.upperBound.doubleValue
        } else if let timeRange = work.content.wallTimeRange {
            startBeat = timeRange.lowerBound.doubleValue
            endBeat = timeRange.upperBound.doubleValue
        } else {
            startBeat = 0
            endBeat = 0
        }

        let duration = endBeat - startBeat

        entries.append(JohnnySonic.Entry(command: .mix,
                                         arguments: .double(startBeat),
                                         .double(duration),
                                         .double(0),
                                         .double(0),
                                         .double(1)))
        entries.append(JohnnySonic.Entry(command: .end))

        return entries
    }

    private static func _pitchNumber(for pitch: Pitch) -> Number {
        clamp(0,
              _pitchNumber(for: pitch.pitchClass) + Number(pitch.octave.intValue * 12),
              127)
    }

    private static func _pitchNumber(for pitchClass: PitchClass) -> Number {
        switch pitchClass {
        case .cDoubleFlat:
            -2

        case .cFlat:
            -1

        case .c,
             .dDoubleFlat:
            0

        case .cSharp,
             .dFlat:
            1

        case .cDoubleSharp,
             .d,
             .eDoubleFlat:
            2

        case .dSharp,
             .eFlat,
             .fDoubleFlat:
            3

        case .dDoubleSharp,
             .e,
             .fFlat:
            4

        case .eSharp,
             .f,
             .gDoubleFlat:
            5

        case .eDoubleSharp,
             .fSharp,
             .gFlat:
            6

        case .aDoubleFlat,
             .fDoubleSharp,
             .g:
            7

        case .aFlat,
             .gSharp:
            8

        case .a,
             .bDoubleFlat,
             .gDoubleSharp:
            9

        case .aSharp,
             .bFlat:
            10

        case .aDoubleSharp,
             .b:
            11

        case .bSharp:
            12

        case .bDoubleSharp:
            13

        default:
            0
        }
    }
}

// MARK: - Sendable

extension JohnnySonic.Converter: Sendable {
}
