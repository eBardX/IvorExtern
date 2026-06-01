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
                                 index: Int) throws -> [DKMCommand] {
        var comment = "Part #\(index)"

        if !part.name.isEmpty {
            comment += ": " + part.name
        }

        var commands: [DKMCommand] = try _makeBoxed(comment: comment)

        part.noteTable.forEach { btime, bdur, sfreq, efreq, _ in
            let startBeat  = convertToBeat(btime)
            let duration   = convertToDuration(bdur)
            let volume     = convertToVolume(part.dynamicMap[btime])
            let location   = convertToLocation(part.panMap[btime])
            let startPitch = convertToPitch(sfreq)
            let endPitch   = convertToPitch(efreq)
            let instrument = part.instrumentMap[btime].stringValue

            if duration > 0 {
                commands.append(.pitchesNote(startBeat: startBeat,
                                             duration: duration,
                                             volume: volume,
                                             location: location,
                                             startPitch: startPitch,
                                             endPitch: endPitch,
                                             instrument: instrument))
            }
        }

        return commands
    }

    private static func _convert(part: Part<BeatTime, NoteNumber>,
                                 index: Int) throws -> [DKMCommand] {
        var comment = "Part #\(index)"

        if !part.name.isEmpty {
            comment += ": " + part.name
        }

        var commands: [DKMCommand] = try _makeBoxed(comment: comment)

        part.noteTable.forEach { btime, bdur, snnum, ennum, _ in
            let startBeat  = convertToBeat(btime)
            let duration   = convertToDuration(bdur)
            let volume     = convertToVolume(part.dynamicMap[btime])
            let location   = convertToLocation(part.panMap[btime])
            let startPitch = convertToPitch(snnum)
            let endPitch   = convertToPitch(ennum)
            let instrument = part.instrumentMap[btime].stringValue

            if duration > 0 {
                commands.append(.pitchesNote(startBeat: startBeat,
                                             duration: duration,
                                             volume: volume,
                                             location: location,
                                             startPitch: startPitch,
                                             endPitch: endPitch,
                                             instrument: instrument))
            }
        }

        return commands
    }

    private static func _convert(parts: [Part<BeatTime, Frequency>]) throws -> [DKMCommand] {
        var commands: [DKMCommand] = []

        for (idx, part) in parts.enumerated() {
            commands += try _convert(part: part,
                                     index: idx + 1)
        }

        return commands
    }

    private static func _convert(parts: [Part<BeatTime, NoteNumber>]) throws -> [DKMCommand] {
        var commands: [DKMCommand] = []

        for (idx, part) in parts.enumerated() {
            commands += try _convert(part: part,
                                     index: idx + 1)
        }

        return commands
    }

    private static func _convert(tempoMap: TempoMap) throws -> [DKMCommand] {
        if tempoMap.isEmpty {
            let tempo = convertToTempo(tempoMap.defaultTempo)

            return [.tempoLine(startBeat: 0,
                               duration: 1,
                               initialTempo: tempo,
                               finalTempo: tempo)]
        }

        var tmpSeq: [(BeatTime, Tempo)] = []

        tempoMap.forEach { btime, tempo, _ in
            tmpSeq.append((btime, tempo))
        }

        return zip(tmpSeq.dropLast(),
                   tmpSeq.dropFirst()).compactMap { elt in
            let startBeat  = convertToBeat(elt.0.0)
            let endBeat    = convertToBeat(elt.1.0)
            let duration   = endBeat - startBeat
            let startTempo = convertToTempo(elt.0.1)
            let endTempo   = convertToTempo(elt.1.1)

            if duration > 0 {
                return .tempoLine(startBeat: startBeat,
                                  duration: duration,
                                  initialTempo: startTempo,
                                  finalTempo: endTempo)
            } else {
                return nil
            }
        }
    }

    private static func _convert(work: Work) throws -> JohnnySonic.Score {
        var commands: [DKMCommand] = try _makeHeader(work: work)

        if let tempoMap = work.tempoMap {
            commands += try _convert(tempoMap: tempoMap)
        }

        switch work.content {
        case let .absoluteBeat(parts, _):
            commands += try _convert(parts: parts)

        case let .keyboardBeat(parts, _):
            commands += try _convert(parts: parts)

        case .standardBeat:
            throw JohnnySonic.Error.unsupportedPitchNotation(work.pitchNotation)

        default:
            throw JohnnySonic.Error.unsupportedTimeBasis(work.timeBasis)
        }

        commands += try _makeTrailer(work: work)

        return JohnnySonic.Score(commands: commands)
    }

    private static func _makeBoxed(comment: String) throws -> [DKMCommand] {
        var commands: [DKMCommand] = []

        let line = "+-" + "-".repeating(to: comment.count) + "-+"

        commands.append(.comment(line))
        commands.append(.comment("| " + comment + " |"))
        commands.append(.comment(line))

        return commands
    }

    private static func _makeHeader(work: Work) throws -> [DKMCommand] {
        var comment = "Work"

        if !work.name.isEmpty {
            comment += ": " + work.name
        }

        return try _makeBoxed(comment: comment)
    }

    private static func _makeTrailer(work: Work) throws -> [DKMCommand] {
        var commands: [DKMCommand] = [.comment("")]

        let startBeat: Double
        let endBeat: Double

        if let timeRange = work.beatTimeRange {
            startBeat = convertToBeat(timeRange.lowerBound)
            endBeat   = convertToBeat(timeRange.upperBound)
        } else {
            startBeat = 0
            endBeat   = 0
        }

        let duration = endBeat - startBeat

        commands.append(.mixLine(startBeat: startBeat,
                                 duration: duration,
                                 gainLossdB: 0,
                                 keepSoundBuffer: false,
                                 sign: 1,
                                 timeOffset: 0))
        commands.append(.end)

        return commands
    }
}

// MARK: - Sendable

extension JohnnySonic.Exporter: Sendable {
}
