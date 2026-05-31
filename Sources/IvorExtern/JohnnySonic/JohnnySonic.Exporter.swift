// © 2025–2026 John Gary Pusey (see LICENSE.md)

internal import Foundation
internal import IvorModel

private import IvorJohnnySonic
private import IvorTiming
private import IvorTuning
private import XestiNumbers
private import XestiText
private import XestiTools

extension JohnnySonic {
    internal struct Exporter {
    }
}

// MARK: - ExporterProtocol

extension JohnnySonic.Exporter: ExporterProtocol {

    // MARK: Internal Instance Properties

    internal var writableFileFormats: [FileFormat] {
        [.dkm]
    }

    // MARK: Internal Instance Methods

    internal func write(works: [Work],
                        as fileFormat: FileFormat) throws -> FileWrapper {
        switch fileFormat {
        case .dkm:
            guard let work = works.first,
                  works.count == 1
            else { throw JohnnySonic.Error.formatFailure(JohnnySonic.Error.multipleWorksNotSupported) }

            let score = try convert(work)
            let data = try JohnnySonic.Formatter().format(score)

            return FileWrapper(regularFileWithContents: data)

        default:
            throw JohnnySonic.Error.unsupportedFileFormat(fileFormat.displayName)
        }
    }
}

// MARK: -

extension JohnnySonic.Exporter {

    // MARK: Internal Instance Methods

    internal func convert(_ work: Work) throws -> JohnnySonic.Score {
        do {
            return try Self._convert(work: work)
        } catch let error as any EnhancedError {
            throw JohnnySonic.Error.convertFailure(error)
        }
    }

    // MARK: Private Type Methods

    private static func _convert(part: Part<BeatTime, Frequency>,
                                 index: Int) throws -> [JohnnySonic.Entry] {
        var comment = "Part #\(index)"

        if !part.name.isEmpty {
            comment += ": " + part.name
        }

        var entries: [JohnnySonic.Entry] = try _makeBoxed(comment: comment)

        part.noteTable.forEach { btime, bdur, sfreq, efreq, _ in
            let startBeat  = btime.doubleValue
            let duration   = bdur.doubleValue
            let volume     = part.dynamicMap[btime].doubleValue * 10 // ???
            let location   = part.panMap[btime].doubleValue
            let startPitch = -sfreq.doubleValue
            let endPitch   = -efreq.doubleValue
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

    private static func _convert(part: Part<BeatTime, NoteNumber>,
                                 index: Int) throws -> [JohnnySonic.Entry] {
        var comment = "Part #\(index)"

        if !part.name.isEmpty {
            comment += ": " + part.name
        }

        var entries: [JohnnySonic.Entry] = try _makeBoxed(comment: comment)

        part.noteTable.forEach { btime, bdur, snnum, ennum, _ in
            let startBeat  = btime.doubleValue
            let duration   = bdur.doubleValue
            let volume     = part.dynamicMap[btime].doubleValue * 10 // ???
            let location   = part.panMap[btime].doubleValue
            let startPitch = snnum.doubleValue
            let endPitch   = ennum.doubleValue
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

    private static func _convert(parts: [Part<BeatTime, Frequency>]) throws -> [JohnnySonic.Entry] {
        var entries: [JohnnySonic.Entry] = []

        for (idx, part) in parts.enumerated() {
            entries += try _convert(part: part,
                                    index: idx + 1)
        }

        return entries
    }

    private static func _convert(parts: [Part<BeatTime, NoteNumber>]) throws -> [JohnnySonic.Entry] {
        var entries: [JohnnySonic.Entry] = []

        for (idx, part) in parts.enumerated() {
            entries += try _convert(part: part,
                                    index: idx + 1)
        }

        return entries
    }

    private static func _convert(tempoMap: TempoMap) throws -> [JohnnySonic.Entry] {
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
            let startBeat  = elt.0.0.doubleValue
            let endBeat    = elt.1.0.doubleValue
            let duration   = endBeat - startBeat
            let startTempo = elt.0.1.doubleValue
            let endTempo   = elt.1.1.doubleValue

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

    private static func _convert(work: Work) throws -> JohnnySonic.Score {
        var entries: [JohnnySonic.Entry] = try _makeHeader(work: work)

        if let tempoMap = work.tempoMap {
            entries += try _convert(tempoMap: tempoMap)
        }

        switch work.content {
        case let .absoluteBeat(parts, _):
            entries += try _convert(parts: parts)

        case let .keyboardBeat(parts, _):
            entries += try _convert(parts: parts)

        case .standardBeat:
            throw JohnnySonic.Error.unsupportedPitchNotation(work.pitchNotation)

        default:
            throw JohnnySonic.Error.unsupportedTimeBasis(work.timeBasis)
        }

        entries += try _makeTrailer(work: work)

        return JohnnySonic.Score(entries: entries)
    }

    private static func _makeBoxed(comment: String) throws -> [JohnnySonic.Entry] {
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

    private static func _makeHeader(work: Work) throws -> [JohnnySonic.Entry] {
        var comment = "Work"

        if !work.name.isEmpty {
            comment += ": " + work.name
        }

        return try _makeBoxed(comment: comment)
    }

    private static func _makeTrailer(work: Work) throws -> [JohnnySonic.Entry] {
        var entries: [JohnnySonic.Entry] = [JohnnySonic.Entry(command: .comment)]

        let startBeat: Double
        let endBeat: Double

        if let timeRange = work.beatTimeRange {
            startBeat = timeRange.lowerBound.doubleValue
            endBeat   = timeRange.upperBound.doubleValue
        } else if let timeRange = work.wallTimeRange {
            startBeat = timeRange.lowerBound.doubleValue
            endBeat   = timeRange.upperBound.doubleValue
        } else {
            startBeat = 0
            endBeat   = 0
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
}

// MARK: - Sendable

extension JohnnySonic.Exporter: Sendable {
}
