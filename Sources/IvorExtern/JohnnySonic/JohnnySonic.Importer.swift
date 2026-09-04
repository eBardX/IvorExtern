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

// MARK: -

extension JohnnySonic.Importer {

    // MARK: Internal Instance Methods

    internal func convert(_ score: JohnnySonic.Score) throws(JohnnySonic.Error) -> Work {
        do {
            return try Self._convert(score: score)
        } catch let error as any EnhancedError {
            throw JohnnySonic.Error.convertFailure(error)
        } catch {
            throw JohnnySonic.Error.convertFailure(nil)
        }
    }

    // MARK: Private Type Methods

    private static func _beatTempos(_ commands: [JohnnySonic.Command]) -> [Int: Double] {
        var beatTempos: [Int: Double] = [:]

        for command in commands {
            guard case let .tempoLine(line) = command
            else { continue }

            let startBeat = Int(line.startBeat.rounded())
            let duration = Int(line.duration.rounded())

            guard duration > 0
            else { continue }

            for i in 0...duration {
                let fraction = (Double(i) + 0.5) / Double(duration)

                beatTempos[startBeat + i] = line.initialTempo + (line.finalTempo - line.initialTempo) * fraction
            }
        }

        return beatTempos
    }

    // An `/End` command terminates the score even if more commands follow —
    // parking material after it is a common DKM convention.
    private static func _commands(precedingEndIn commands: [JohnnySonic.Command]) -> [JohnnySonic.Command] {
        guard let endIndex = commands.firstIndex(where: { if case .end = $0 { true } else { false } })
        else { return commands }

        return Array(commands[..<endIndex])
    }

    // Whether a note was written as a keyboard pitch number, or a raw
    // frequency (negative pitch), and what that number was, is read
    // straight from the validated score — both branches walk
    // `activeCommands` directly, and neither goes through a resolver.
    private static func _convert(score: JohnnySonic.Score) throws -> Work {
        let (normalized, _) = JohnnySonic.Normalizer().normalize(score)
        let (validated, issues) = try JohnnySonic.Validator().validate(normalized)

        guard issues.isEmpty
        else { throw JohnnySonic.Error.validationFailure(issues) }

        let workName = determineWorkName(validated)

        // An `/End` command terminates the score even if more commands
        // follow — parking material after it is a common DKM convention.
        let activeCommands = _commands(precedingEndIn: validated.commands)
        let tempoMap = _makeTempoMap(activeCommands)

        var hasPitchesNotes = false
        var hasAbsolutePitch = false

        for command in activeCommands {
            if case let .pitchesNote(note) = command {
                hasPitchesNotes = true

                if note.startPitch < 0 || note.endPitch < 0 {
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
            let tuning = Tuning(activeCommands)
            let parts = _convertAbsolute(activeCommands, tuning: tuning)

            return Work(name: workName,
                        content: .absoluteBeat(parts,
                                               tempoMap))
        } else {
            let parts = try _convertKeyboard(activeCommands)

            return Work(name: workName,
                        content: .keyboardBeat(parts,
                                               tempoMap))
        }
    }

    private static func _convertAbsolute(_ commands: [JohnnySonic.Command], tuning: Tuning) -> [Part<BeatTime, Frequency>] {
        let (instrumentOrder, notesByInstrument) = _pitchesNotes(byInstrumentIn: commands)

        return instrumentOrder.map { _convertAbsolute(notesByInstrument[$0] ?? [], tuning: tuning) }
    }

    private static func _convertAbsolute(_ notes: [DKMPitchesNote], tuning: Tuning) -> Part<BeatTime, Frequency> {
        var noteTable = NoteTable<BeatTime, Frequency>()
        var dynamicMap = DynamicMap<BeatTime>()
        var panMap = PanMap<BeatTime>()

        for note in notes.sorted(by: { $0.startBeat < $1.startBeat }) {
            guard let sfreq = convertToFrequency(tuning.frequency(forPitch: note.startPitch)),
                  let efreq = convertToFrequency(tuning.frequency(forPitch: note.endPitch))
            else { continue }

            let attackTime = convertToBeatTime(note.startBeat)
            let bdur = convertToBeatDuration(note.duration)

            noteTable.insert(attack: attackTime,
                             duration: bdur,
                             startPitch: sfreq,
                             endPitch: efreq)

            if let dynamic = convertToDynamic(note.volume) {
                dynamicMap.insert(time: attackTime,
                                  dynamic: dynamic)
            }

            if let pan = convertToPan(note.location) {
                panMap.insert(time: attackTime,
                              pan: pan)
            }
        }

        return Part(name: notes.first?.instrument ?? "",
                    noteTable: noteTable,
                    dynamicMap: dynamicMap,
                    instrumentMap: _makeInstrumentMap(notes),
                    panMap: panMap)
    }

    private static func _convertKeyboard(_ commands: [JohnnySonic.Command]) throws(JohnnySonic.Error) -> [Part<BeatTime, NoteNumber>] {
        let (instrumentOrder, notesByInstrument) = _pitchesNotes(byInstrumentIn: commands)
        var parts: [Part<BeatTime, NoteNumber>] = []

        for instrument in instrumentOrder {
            try parts.append(_convertKeyboard(notesByInstrument[instrument] ?? []))
        }

        return parts
    }

    private static func _convertKeyboard(_ notes: [DKMPitchesNote]) throws(JohnnySonic.Error) -> Part<BeatTime, NoteNumber> {
        var noteTable = NoteTable<BeatTime, NoteNumber>()
        var dynamicMap = DynamicMap<BeatTime>()
        var panMap = PanMap<BeatTime>()

        for note in notes.sorted(by: { $0.startBeat < $1.startBeat }) {
            guard let snnum = convertToNoteNumber(note.startPitch),
                  let ennum = convertToNoteNumber(note.endPitch)
            else { throw JohnnySonic.Error.inconsistentPitchNotation }

            let attackTime = convertToBeatTime(note.startBeat)
            let bdur = convertToBeatDuration(note.duration)

            noteTable.insert(attack: attackTime,
                             duration: bdur,
                             startPitch: snnum,
                             endPitch: ennum)

            if let dynamic = convertToDynamic(note.volume) {
                dynamicMap.insert(time: attackTime,
                                  dynamic: dynamic)
            }

            if let pan = convertToPan(note.location) {
                panMap.insert(time: attackTime,
                              pan: pan)
            }
        }

        return Part(name: notes.first?.instrument ?? "",
                    noteTable: noteTable,
                    dynamicMap: dynamicMap,
                    instrumentMap: _makeInstrumentMap(notes),
                    panMap: panMap)
    }

    // Every `/Pitches` line carries its own instrument name — instrument can
    // genuinely change from note to note — so this reads it off each note
    // individually rather than assuming one value for the whole part.
    // `_pitchesNotes(byInstrumentIn:)` happens to group notes so every note
    // reaching a given `Part` already shares one instrument, but that's a
    // property of the grouping, not of the format, and this stays correct
    // independent of it.
    private static func _makeInstrumentMap(_ notes: [DKMPitchesNote]) -> InstrumentMap<BeatTime> {
        var instrumentMap = InstrumentMap<BeatTime>()

        for note in notes {
            guard let instrument = convertToInstrument(note.instrument)
            else { continue }

            instrumentMap.insert(time: convertToBeatTime(note.startBeat),
                                 instrument: instrument)
        }

        return instrumentMap
    }

    // The reference JohnnySonic player (`ProcessTempo` / `ConvertTempoToTime`
    // in the original C source) does *not* vary tempo continuously across a
    // `/Tempo` line: it holds a constant BPM for each whole beat, computed as
    // the ramp's midpoint-sampled average over that beat —
    // `initialTempo + (finalTempo - initialTempo) * (i - startBeat + 0.5) /
    // duration` — then jumps instantly at the next beat boundary. Its loop
    // runs one beat past the line's declared range (`i <= startBeat +
    // duration`), so a contiguous next line's own first beat naturally
    // overwrites that trailing sample; an isolated line leaves it in effect
    // until whatever comes next. `_beatTempos` reproduces that table exactly
    // (last write wins for overlapping lines, matching the C array's
    // sequential overwrite), and `_makeTempoMap` renders it into `TempoMap`
    // as a true step function — reasserting the previously held tempo at
    // each beat where the value changes so `TempoMap` reads it as an instant
    // jump rather than interpolating across the boundary — with beats before
    // the first tempo line and gaps between non-contiguous lines holding the
    // reference's own default/previous tempo.
    private static func _makeTempoMap(_ commands: [JohnnySonic.Command]) -> TempoMap {
        let beatTempos = _beatTempos(commands)

        guard let lastBeat = beatTempos.keys.max()
        else { return TempoMap() }

        var tempoMap = TempoMap()
        var heldTempo = Tempo.default

        for beat in 0...lastBeat {
            guard let bpm = beatTempos[beat]
            else { continue }

            let tempo = convertToTempo(bpm)

            guard tempo != heldTempo
            else { continue }

            tempoMap.insert(beatTime: convertToBeatTime(Double(beat)),
                            tempo: heldTempo)
            tempoMap.insert(beatTime: convertToBeatTime(Double(beat)),
                            tempo: tempo)

            heldTempo = tempo
        }

        return tempoMap
    }

    // Groups `.pitchesNote` commands by instrument, preserving each
    // instrument's first-appearance order — both note-table walks below
    // share this shape.
    private static func _pitchesNotes(byInstrumentIn commands: [JohnnySonic.Command]) -> (order: [String], byInstrument: [String: [DKMPitchesNote]]) {
        var notesByInstrument: [String: [DKMPitchesNote]] = [:]
        var instrumentOrder: [String] = []

        for command in commands {
            guard case let .pitchesNote(note) = command
            else { continue }

            if notesByInstrument[note.instrument] == nil {
                instrumentOrder.append(note.instrument)
            }

            notesByInstrument[note.instrument, default: []].append(note)
        }

        return (instrumentOrder, notesByInstrument)
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
                       as fileFormat: FileFormat) throws(JohnnySonic.Error) -> [Work] {
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

// MARK: - Sendable

extension JohnnySonic.Importer: Sendable {
}
