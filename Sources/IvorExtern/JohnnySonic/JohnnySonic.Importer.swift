// © 2025–2026 John Gary Pusey (see LICENSE.md)

internal import Foundation
internal import IvorModel

private import IvorJohnnySonic
private import IvorTiming
private import IvorTuning
private import XestiTools

extension JohnnySonic {
    internal struct Importer {
    }
}

// MARK: - ImporterProtocol

extension JohnnySonic.Importer: ImporterProtocol {

    // MARK: Internal Instance Properties

    internal var readableFileFormats: [FileFormat] {
        [.dkm]
    }

    // MARK: Internal Instance Methods

    internal func read(from file: FileWrapper,
                       as fileFormat: FileFormat) throws -> [Work] {
        switch fileFormat {
        case .dkm:
            guard let data = file.regularFileContents
            else { throw JohnnySonic.Error.parseFailure(nil) }

            let score = try JohnnySonic.Parser().parse(data)
            let work = try convert(score)

            return [work]

        default:
            throw JohnnySonic.Error.unsupportedFileFormat(fileFormat.displayName)
        }
    }
}

// MARK: -

extension JohnnySonic.Importer {

    // MARK: Internal Instance Methods

    internal func convert(_ score: JohnnySonic.Score) throws -> Work {
        do {
            return try Self._convert(score: score)
        } catch let error as any EnhancedError {
            throw JohnnySonic.Error.convertFailure(error)
        }
    }

    // MARK: Private Type Methods

    private static func _convert(score: JohnnySonic.Score) throws -> Work {
        let workName = determineWorkName(score)
        let tempoMap = _makeTempoMap(score.commands)

        var hasPitchesNotes = false
        var hasAbsolutePitch = false

        for command in score.commands {
            if case let .pitchesNote(_, _, _, _, startPitch, endPitch, _) = command {
                hasPitchesNotes = true

                if startPitch < 0 || endPitch < 0 {
                    hasAbsolutePitch = true
                    break
                }
            }
        }

        guard hasPitchesNotes
        else { return Work(name: workName,
                           content: .keyboardBeat([],
                                                  tempoMap)) }

        if hasAbsolutePitch {
            let part = try _convertAbsolute(score.commands)

            return Work(name: workName,
                        content: .absoluteBeat([part],
                                               tempoMap))
        } else {
            let part = try _convertKeyboard(score.commands)

            return Work(name: workName,
                        content: .keyboardBeat([part],
                                               tempoMap))
        }
    }

    private static func _convertAbsolute(_ commands: [JohnnySonic.Command]) throws -> Part<BeatTime, Frequency> {
        var noteTable = NoteTable<BeatTime, Frequency>()
        var dynamicMap = DynamicMap<BeatTime>()
        var panMap = PanMap<BeatTime>()

        for command in commands {
            guard case let .pitchesNote(startBeat, duration, volume, location, startPitch, endPitch, _) = command
            else { continue }

            guard let sfreq = convertToFrequency(startPitch),
                  let efreq = convertToFrequency(endPitch)
            else { throw JohnnySonic.Error.inconsistentPitchNotation }

            let attackTime = convertToBeatTime(startBeat)
            let bdur = convertToBeatDuration(duration)

            noteTable.insert(attack: attackTime,
                             duration: bdur,
                             startPitch: sfreq,
                             endPitch: efreq)

            if let dynamic = convertToDynamic(volume) {
                dynamicMap.insert(time: attackTime,
                                  dynamic: dynamic)
            }

            if let pan = convertToPan(location) {
                panMap.insert(time: attackTime,
                              pan: pan)
            }
        }

        return Part(name: "",
                    noteTable: noteTable,
                    dynamicMap: dynamicMap,
                    panMap: panMap)
    }

    private static func _convertKeyboard(_ commands: [JohnnySonic.Command]) throws -> Part<BeatTime, NoteNumber> {
        var noteTable = NoteTable<BeatTime, NoteNumber>()
        var dynamicMap = DynamicMap<BeatTime>()
        var panMap = PanMap<BeatTime>()

        for command in commands {
            guard case let .pitchesNote(startBeat, duration, volume, location, startPitch, endPitch, _) = command
            else { continue }

            guard let snnum = convertToNoteNumber(startPitch),
                  let ennum = convertToNoteNumber(endPitch)
            else { throw JohnnySonic.Error.inconsistentPitchNotation }

            let attackTime = convertToBeatTime(startBeat)
            let bdur = convertToBeatDuration(duration)

            noteTable.insert(attack: attackTime,
                             duration: bdur,
                             startPitch: snnum,
                             endPitch: ennum)

            if let dynamic = convertToDynamic(volume) {
                dynamicMap.insert(time: attackTime,
                                  dynamic: dynamic)
            }

            if let pan = convertToPan(location) {
                panMap.insert(time: attackTime,
                              pan: pan)
            }
        }

        return Part(name: "",
                    noteTable: noteTable,
                    dynamicMap: dynamicMap,
                    panMap: panMap)
    }

    private static func _makeTempoMap(_ commands: [JohnnySonic.Command]) -> TempoMap {
        var tempoEntries: [BeatTime: Tempo] = [:]

        for command in commands {
            guard case let .tempoLine(startBeat, duration, initialTempo, finalTempo) = command
            else { continue }

            let startTime = convertToBeatTime(startBeat)
            let endTime = convertToBeatTime(startBeat + duration)

            if tempoEntries[startTime] == nil {
                tempoEntries[startTime] = convertToTempo(initialTempo)
            }

            tempoEntries[endTime] = convertToTempo(finalTempo)
        }

        var tempoMap = TempoMap()

        for beatTime in tempoEntries.keys.sorted() {
            if let tempo = tempoEntries[beatTime] {
                tempoMap.insert(beatTime: beatTime,
                                tempo: tempo)
            }
        }

        return tempoMap
    }
}

// MARK: - Sendable

extension JohnnySonic.Importer: Sendable {
}
