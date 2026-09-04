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

// MARK: -

extension JohnnySonic.Exporter {

    // MARK: Internal Instance Methods

    // Pitches are always written as literal Hz. `JohnnySonic.Importer`
    // parses a `/Tuning` directive to convert scale-degree pitches into
    // absolute Hz; this exporter never emits `/Tuning`, so the
    // frequencies round-trip numerically but the declarative tuning-scale
    // context that produced them is permanently lost. Reconstructing it
    // would require the model to retain the originating scale, which is
    // out of scope — documented, not fixed.
    internal func convert(_ work: Work) throws(JohnnySonic.Error) -> JohnnySonic.Score {
        do {
            return try Self._convert(work: work)
        } catch let error as any EnhancedError {
            throw JohnnySonic.Error.convertFailure(error)
        } catch {
            throw JohnnySonic.Error.convertFailure(nil)
        }
    }

    // MARK: Private Type Methods

    private static func _convert(part: Part<BeatTime, Frequency>,
                                 index: Int) throws(JohnnySonic.Error) -> [DKMCommand] {
        var comment = "Part #\(index)"

        if !part.name.isEmpty {
            comment += ": " + part.name
        }

        var commands: [DKMCommand] = try _makeBoxed(comment: comment)

        part.noteTable.forEach { _, btime, bdur, sfreq, efreq, _ in
            let startBeat  = convertToJohnnySonicBeat(btime)
            let duration   = convertToJohnnySonicDuration(bdur)
            let volume     = convertToJohnnySonicVolume(part.dynamicMap[btime])
            let location   = convertToJohnnySonicLocation(part.panMap[btime])
            let startPitch = convertToJohnnySonicPitch(sfreq)
            let endPitch   = convertToJohnnySonicPitch(efreq)
            let instrument = part.instrumentMap[btime].stringValue

            if duration > 0 {
                commands.append(.pitchesNote(DKMPitchesNote(startBeat: startBeat,
                                                            duration: duration,
                                                            volume: volume,
                                                            location: location,
                                                            startPitch: startPitch,
                                                            endPitch: endPitch,
                                                            instrument: instrument)))
            }
        }

        return commands
    }

    private static func _convert(part: Part<BeatTime, NoteNumber>,
                                 index: Int) throws(JohnnySonic.Error) -> [DKMCommand] {
        var comment = "Part #\(index)"

        if !part.name.isEmpty {
            comment += ": " + part.name
        }

        var commands: [DKMCommand] = try _makeBoxed(comment: comment)

        part.noteTable.forEach { _, btime, bdur, snnum, ennum, _ in
            let startBeat  = convertToJohnnySonicBeat(btime)
            let duration   = convertToJohnnySonicDuration(bdur)
            let volume     = convertToJohnnySonicVolume(part.dynamicMap[btime])
            let location   = convertToJohnnySonicLocation(part.panMap[btime])
            let startPitch = convertToJohnnySonicPitch(snnum)
            let endPitch   = convertToJohnnySonicPitch(ennum)
            let instrument = part.instrumentMap[btime].stringValue

            if duration > 0 {
                commands.append(.pitchesNote(DKMPitchesNote(startBeat: startBeat,
                                                            duration: duration,
                                                            volume: volume,
                                                            location: location,
                                                            startPitch: startPitch,
                                                            endPitch: endPitch,
                                                            instrument: instrument)))
            }
        }

        return commands
    }

    private static func _convert(parts: [Part<BeatTime, Frequency>]) throws(JohnnySonic.Error) -> [DKMCommand] {
        var commands: [DKMCommand] = []

        for (idx, part) in parts.enumerated() {
            commands += try _convert(part: part,
                                     index: idx + 1)
        }

        return commands
    }

    private static func _convert(parts: [Part<BeatTime, NoteNumber>]) throws(JohnnySonic.Error) -> [DKMCommand] {
        var commands: [DKMCommand] = []

        for (idx, part) in parts.enumerated() {
            commands += try _convert(part: part,
                                     index: idx + 1)
        }

        return commands
    }

    private static func _convert(tempoMap: TempoMap,
                                 work: Work) throws(JohnnySonic.Error) -> [DKMCommand] {
        if tempoMap.isEmpty {
            let tempo = convertToJohnnySonicTempo(tempoMap.defaultTempo)

            return [.tempoLine(DKMTempoLine(startBeat: 0,
                                            duration: 1,
                                            initialTempo: tempo,
                                            finalTempo: tempo))]
        }

        var tmpSeq: [(BeatTime, Tempo)] = []

        tempoMap.forEach { _, btime, tempo, _ in
            tmpSeq.append((btime, tempo))
        }

        var commands: [DKMCommand] = zip(tmpSeq.dropLast(),
                                         tmpSeq.dropFirst()).compactMap { elt in
            let startBeat  = convertToJohnnySonicBeat(elt.0.0)
            let endBeat    = convertToJohnnySonicBeat(elt.1.0)
            let duration   = endBeat - startBeat
            let startTempo = convertToJohnnySonicTempo(elt.0.1)
            let endTempo   = convertToJohnnySonicTempo(elt.1.1)

            if duration > 0 {
                return .tempoLine(DKMTempoLine(startBeat: startBeat,
                                               duration: duration,
                                               initialTempo: startTempo,
                                               finalTempo: endTempo))
            } else {
                return nil
            }
        }

        // The loop above only covers the intervals *between* consecutive
        // entries, dropping the segment from the last entry through the
        // end of the piece. Emit a trailing flat segment covering it,
        // reusing the same `work.beatTimeRange` upper bound as
        // `_makeTrailer(work:)`.
        if let lastEntry = tmpSeq.last,
           let timeRange = work.beatTimeRange {
            let startBeat = convertToJohnnySonicBeat(lastEntry.0)
            let endBeat   = convertToJohnnySonicBeat(timeRange.upperBound)
            let duration  = endBeat - startBeat
            let tempo     = convertToJohnnySonicTempo(lastEntry.1)

            if duration > 0 {
                commands.append(.tempoLine(DKMTempoLine(startBeat: startBeat,
                                                        duration: duration,
                                                        initialTempo: tempo,
                                                        finalTempo: tempo)))
            }
        }

        return commands
    }

    private static func _convert(work: Work) throws(JohnnySonic.Error) -> JohnnySonic.Score {
        var commands: [DKMCommand] = try _makeHeader(work: work)

        if let tempoMap = work.tempoMap {
            commands += try _convert(tempoMap: tempoMap,
                                     work: work)
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

    private static func _makeBoxed(comment: String) throws(JohnnySonic.Error) -> [DKMCommand] {
        var commands: [DKMCommand] = []

        let line = "+-" + "-".repeating(to: comment.count) + "-+"

        commands.append(.comment(line))
        commands.append(.comment("| " + comment + " |"))
        commands.append(.comment(line))

        return commands
    }

    private static func _makeHeader(work: Work) throws(JohnnySonic.Error) -> [DKMCommand] {
        var comment = "Work"

        if !work.name.isEmpty {
            comment += ": " + work.name
        }

        return try _makeBoxed(comment: comment)
    }

    private static func _makeTrailer(work: Work) throws(JohnnySonic.Error) -> [DKMCommand] {
        var commands: [DKMCommand] = [.comment("")]

        let startBeat: JohnnySonic.Beat
        let endBeat: JohnnySonic.Beat

        if let timeRange = work.beatTimeRange {
            startBeat = convertToJohnnySonicBeat(timeRange.lowerBound)
            endBeat   = convertToJohnnySonicBeat(timeRange.upperBound)
        } else {
            startBeat = 0
            endBeat   = 0
        }

        let duration = endBeat - startBeat

        if duration > 0 {
            commands.append(.mixLine(DKMMixLine(startBeat: startBeat,
                                                duration: duration,
                                                gainLossdB: 0,
                                                keepSoundBuffer: false,
                                                sign: 1,
                                                timeOffset: 0)))
        }

        commands.append(.end)

        return commands
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
                        as fileFormat: FileFormat) throws(JohnnySonic.Error) -> FileWrapper {
        switch fileFormat {
        case .dkm:
            guard !works.isEmpty
            else { throw JohnnySonic.Error.noWorksToExport }

            guard let work = works.first,
                  works.count == 1
            else { throw JohnnySonic.Error.multipleWorksNotSupported }

            let score = try convert(work)
            let data = try JohnnySonic.Formatter().format(score)

            return FileWrapper(regularFileWithContents: data)

        default:
            throw JohnnySonic.Error.unsupportedFileFormat(fileFormat.displayName)
        }
    }
}

// MARK: - Sendable

extension JohnnySonic.Exporter: Sendable {
}
