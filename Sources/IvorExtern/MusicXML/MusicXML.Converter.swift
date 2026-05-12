internal import IvorModel

private import IvorMusicXML
private import IvorTiming
private import IvorTuning
private import XestiTools

extension MusicXML {

    // MARK: Internal Instance Methods

    internal struct Converter {
    }
}

// MARK: -

extension MusicXML.Converter {

    // MARK: Internal Instance Methods

    internal func convert(_ score: MusicXML.ScorePW) throws -> Work {
        do {
            return try Self._convertToWork(score)
        } catch let error as any EnhancedError {
            throw MusicXML.Error.convertFailure(error)
        }
    }

    internal func convert(_ score: MusicXML.ScoreTW) throws -> Work {
        do {
            return try Self._convertToWork(score)
        } catch let error as any EnhancedError {
            throw MusicXML.Error.convertFailure(error)
        }
    }

    // MARK: Private Type Methods

    private static func _convertMusicXMLMeasure(_ measure: MusicXML.MeasurePW,
                                                _ context: inout Self.Context) throws {
        try _convertMusicXMLMusicItems(measure.items, &context)
    }

    private static func _convertMusicXMLMeasures(_ measures: [MusicXML.MeasurePW],
                                                 _ context: inout Self.Context) throws {
        for measure in measures {
            try _convertMusicXMLMeasure(measure, &context)
        }
    }

    private static func _convertMusicXMLMusicItem(_ musicItem: MusicXML.MusicItem,
                                                  _ context: inout Self.Context) throws {
        switch musicItem {
        case let .attributes(duration):
            context.currentDivisions = duration

        case let .backup(duration):
            context.emitNoteInProgress()

            context.currentBeatTime -= context.makeBeatDuration(duration)

            context.previousBeatTime = context.currentBeatTime

        case let .forward(duration):
            context.emitNoteInProgress()

            context.currentBeatTime += context.makeBeatDuration(duration)

            context.previousBeatTime = context.currentBeatTime

        case .graceNote:
            break       // ignore grace notes for now…

        case let .note(note):
            try _convertMusicXMLNote(note, &context)

        default:
            break
        }
    }

    private static func _convertMusicXMLMusicItems(_ musicItems: [MusicXML.MusicItem],
                                                   _ context: inout Self.Context) throws {
        for musicItem in musicItems {
            try _convertMusicXMLMusicItem(musicItem, &context)
        }
    }

    private static func _convertMusicXMLNote(_ note: MusicXML.Note,
                                             _ context: inout Self.Context) throws {
        let tmpDuration = context.makeBeatDuration(note.duration)
        let hasStart = note.ties.contains(.start)
        let hasStop = note.ties.contains(.stop)

        switch (hasStart, hasStop) {
        case (false, false),
            (true, false):
            context.emitNoteInProgress()

            context.currentBeatDuration = tmpDuration

        case (false, true),
            (true, true):
            context.currentBeatDuration += tmpDuration
        }

        switch note.value {
        case let .pitch(pitch):
            context.currentStandardPitch = try _convertMusicXMLPitch(pitch, &context)

        default:
            context.currentStandardPitch = nil
        }

        context.isChord = note.isChord
        context.noteInProgress = true
    }

    private static func _convertMusicXMLPitch(_ pitch: MusicXML.Pitch,
                                              _ context: inout Self.Context) throws -> Pitch {
        try convertToStandardPitch(pitch)
    }

    private static func _convertToPart(_ part: MusicXML.PartPW,
                                       _ scoreParts: [MusicXML.ScorePart]) throws -> Part<BeatTime, Pitch> {
        var context = Self.Context()

        try _convertMusicXMLMeasures(part.measures, &context)

        return Part(name: determinePartName(part, scoreParts),
                    noteTable: context.noteTable)
    }

    private static func _convertToParts(_ parts: [MusicXML.PartPW],
                                        _ scoreParts: [MusicXML.ScorePart]) throws -> [Part<BeatTime, Pitch>] {
        try parts.map { try _convertToPart($0, scoreParts) }
    }

    private static func _convertToWork(_ score: MusicXML.ScorePW) throws -> Work {
        guard score.parts.count == score.partList.scoreParts.count
        else { throw MusicXML.Error.partMismatch }

        return try Work(name: determineWorkName(score),
                        content: .standardBeat(_convertToParts(score.parts,
                                                               score.partList.scoreParts),
                                               TempoMap()))
    }

    private static func _convertToWork(_ score: MusicXML.ScoreTW) throws -> Work {
        throw MusicXML.Error.unsupportedScoreFormat("timewise")
    }
}

// MARK: - Sendable

extension MusicXML.Converter: Sendable {
}
