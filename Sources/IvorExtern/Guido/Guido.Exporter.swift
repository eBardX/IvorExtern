// © 2025–2026 John Gary Pusey (see LICENSE.md)

internal import Foundation
internal import IvorGuido
internal import IvorModel

private import IvorTiming
private import IvorTuning
private import XestiNumbers
private import XestiTools

extension Guido {
    // Not a namespace: `ExporterProtocol`'s instance members live in the
    // following extension, invisible to this check from here.
    // swiftformat:disable:next enumNamespaces
    internal struct Exporter { // swiftlint:disable:this convenience_type

        // MARK: Private Nested Types

        private enum DynamicAnnotation {
            case mark(time: BeatTime, dynamic: Dynamic)
            case ramp(start: BeatTime, startDynamic: Dynamic, end: BeatTime, endDynamic: Dynamic, direction: GMNDynamicRamp.Direction)
        }

        private struct Event {

            // MARK: Fileprivate Instance Properties

            fileprivate let attack: BeatTime
            fileprivate let duration: BeatDuration
            fileprivate var pitches: [IvorTuning.Pitch]

            fileprivate var end: BeatTime {
                BeatTime(attack.numberValue + duration.numberValue)
            }
        }

        private struct Ramp {

            // MARK: Fileprivate Instance Properties

            fileprivate let direction: GMNDynamicRamp.Direction
            fileprivate let end: BeatTime
            fileprivate let endDynamic: Dynamic
            fileprivate let startDynamic: Dynamic
        }
    }
}

// MARK: -

extension Guido.Exporter {

    // MARK: Internal Instance Methods

    internal func convert(_ work: Work) throws(Guido.Error) -> Guido.Score {
        do {
            return try Self._convert(work: work)
        } catch let error as any EnhancedError {
            throw Guido.Error.convertFailure(error)
        } catch {
            throw Guido.Error.convertFailure(nil)
        }
    }

    // MARK: Private Type Methods

    private static func _barTimes(measureCount: UInt) -> [BeatTime] {
        var barTimes: [BeatTime] = []
        var barBeat: UInt = 4

        while barBeat < measureCount * 4 {
            barTimes.append(BeatTime(Number(numerator: barBeat, denominator: 1)))
            barBeat += 4
        }

        return barTimes
    }

    // The sorted union of every time this part's body needs to notice: `.zero`
    // and the work's end, every bar line, every note's attack and end, and
    // every tempo/instrument/dynamic annotation's own time. Splitting a note
    // at one of these — even one with no note of its own — is what lets a
    // tempo change, instrument change, or dynamic mark/ramp boundary land
    // exactly where the model says it should.
    private static func _boundaries(events: [Event],
                                    directives: [(BeatTime, GMNInstrument)],
                                    tempos: [(BeatTime, GMNTempo)],
                                    annotations: [DynamicAnnotation],
                                    barTimes: [BeatTime],
                                    endTime: BeatTime) -> [BeatTime] {
        var boundaries: Set<BeatTime> = [.zero, endTime]

        for barTime in barTimes {
            boundaries.insert(barTime)
        }

        for event in events {
            boundaries.insert(event.attack)
            boundaries.insert(event.end)
        }

        for (time, _) in directives {
            boundaries.insert(time)
        }

        for (time, _) in tempos {
            boundaries.insert(time)
        }

        for annotation in annotations {
            switch annotation {
            case let .mark(time, _):
                boundaries.insert(time)

            case let .ramp(start, _, end, _, _):
                boundaries.insert(start)
                boundaries.insert(end)
            }
        }

        return boundaries.sorted()
    }

    private static func _convert(work: Work) throws(Guido.Error) -> Guido.Score {
        guard case let .standardBeat(parts, tempoMap) = work.content
        else {
            guard work.pitchNotation == .standard
            else { throw Guido.Error.unsupportedPitchNotation(work.pitchNotation) }

            throw Guido.Error.unsupportedTimeBasis(work.timeBasis)
        }

        let measureCount = _measureCount(work: work)
        let voices = try _makeBody(work: work,
                                   parts: parts,
                                   measureCount: measureCount,
                                   tempoMap: tempoMap)

        return Guido.Score(variables: [], voices: voices)
    }

    // Reduces a dynamic map's (time, level) entries into mark/ramp
    // annotations, per the module-wide positional convention: two entries at
    // the *same* time are an instantaneous step, emitted as a single
    // `\intensity` mark using the post-jump level; two entries at *different*
    // times are a ramp. A trailing unpaired entry gets a plain mark.
    private static func _dynamicAnnotations(_ dynamicMap: DynamicMap<BeatTime>) -> [DynamicAnnotation] {
        guard !dynamicMap.isEmpty
        else { return [] }

        var entries: [(BeatTime, Dynamic)] = []

        dynamicMap.forEach { _, time, dynamic, _ in entries.append((time, dynamic)) }

        var annotations: [DynamicAnnotation] = []
        var index = 0

        while index < entries.count {
            let (time, dynamic) = entries[index]

            if index + 1 < entries.count, entries[index + 1].0 == time {
                let (_, nextDynamic) = entries[index + 1]

                annotations.append(.mark(time: time, dynamic: nextDynamic))
                index += 2
            } else if index + 1 < entries.count {
                let (endTime, endDynamic) = entries[index + 1]
                let direction: GMNDynamicRamp.Direction = endDynamic > dynamic ? .crescendo : .diminuendo

                annotations.append(.ramp(start: time,
                                         startDynamic: dynamic,
                                         end: endTime,
                                         endDynamic: endDynamic,
                                         direction: direction))
                index += 2
            } else {
                annotations.append(.mark(time: time, dynamic: dynamic))
                index += 1
            }
        }

        return annotations
    }

    // Every note table entry is walked once, in time order. Consecutive
    // entries sharing an attack time and a duration are a chord; anything
    // else stays a separate event. Ending pitch is dropped — a glissando
    // exports at its start pitch, per the module-wide rule.
    private static func _events(_ noteTable: NoteTable<BeatTime, Pitch>) -> [Event] {
        var events: [Event] = []

        noteTable.forEach { _, attack, duration, startPitch, _, _ in
            if let last = events.last,
               last.attack == attack,
               last.duration == duration {
                events[events.count - 1].pitches.append(startPitch)
            } else {
                events.append(Event(attack: attack,
                                    duration: duration,
                                    pitches: [startPitch]))
            }
        }

        return events
    }

    private static func _instrumentDirectives(_ instrumentMap: InstrumentMap<BeatTime>) -> [(BeatTime, GMNInstrument)] {
        var directives: [(BeatTime, GMNInstrument)] = []

        instrumentMap.forEach { _, time, instrument, _ in
            directives.append((time, GMNInstrument(name: instrument.stringValue,
                                                   midi: generalMIDIProgramNumber(name: instrument.stringValue))))
        }

        return directives
    }

    private static func _makeBody(work: Work,
                                  parts: [Part<BeatTime, Pitch>],
                                  measureCount: UInt,
                                  tempoMap: TempoMap) throws(Guido.Error) -> [Guido.Voice] {
        var voices: [Guido.Voice] = []

        for index in parts.indices {
            var symbols: [GMNSymbol] = [.tag(.meter(GMNMeter(type: "4/4")))]

            if index == 0, !work.name.isEmpty {
                symbols.append(.tag(.titleBlock(GMNTitleBlock(kind: .title, text: work.name))))
            }

            // `\instrument`'s `name` is Guido's only per-voice identity
            // carrier — `determinePartName(_:)` reads the *first* one found
            // in the voice — so a non-empty part name always gets one, ahead
            // of any real instrument-map-driven tag below. When both land at
            // the same time the real tag's later `insert` simply overwrites
            // this one's entry in the recovered `InstrumentMap`, so neither
            // clobbers the other on round trip. A part with no name and no
            // instrument map entries emits nothing here, so it costs nothing
            // when there's nothing to preserve.
            if !parts[index].name.isEmpty {
                symbols.append(.tag(.instrument(GMNInstrument(name: parts[index].name))))
            }

            // Tempo is score-wide, not per-voice, but `Guido.Importer`
            // flattens every voice's `\tempo` events into one `TempoMap`
            // (`contexts.flatMap(\.tempoEvents)`) — writing it into every
            // voice would multiply each entry once per part. Only the first
            // voice carries it.
            symbols += try _makePartBody(part: parts[index],
                                         measureCount: measureCount,
                                         tempoMap: index == 0 ? tempoMap : TempoMap())

            voices.append(GMNVoice(symbols: symbols))
        }

        return voices
    }

    // Lays one part's notes onto the fixed 4/4 grid: a note or chord
    // crossing a barline splits into segments tied by a bare `\tieEnd`
    // marker (see `_makeChunks`'s discussion), gaps become rests, and every
    // measure sums to exactly 4 beats.
    //
    // `Guido.Importer.Walker._handleTag` flushes the pending note and clears
    // the tie-armed flag on *every* tag other than `\tieEnd` itself, so a
    // barline (or any directive/mark) can never appear between two segments
    // of the same tied note without breaking the tie — the loop below skips
    // the barline at any boundary a tie continues across instead. Guido
    // barlines carry no timing information, so deferring one past a tied
    // note is a purely cosmetic reordering, not a loss.
    private static func _makeChunks(events: [Event],
                                    directives: [(BeatTime, GMNInstrument)],
                                    tempos: [(BeatTime, GMNTempo)],
                                    annotations: [DynamicAnnotation],
                                    barTimes: [BeatTime],
                                    sortedBoundaries: [BeatTime]) throws(Guido.Error) -> [(start: BeatTime, symbols: [GMNSymbol])] {
        var chunks: [(start: BeatTime, symbols: [GMNSymbol])] = []
        var directiveIndex = 0
        var tempoIndex = 0

        for index in 0..<(sortedBoundaries.count - 1) {
            let start = sortedBoundaries[index]
            let end = sortedBoundaries[index + 1]

            guard start < end
            else { continue }

            var symbols: [GMNSymbol] = []

            while tempoIndex < tempos.count, tempos[tempoIndex].0 <= start {
                symbols.append(.tag(.tempo(tempos[tempoIndex].1)))
                tempoIndex += 1
            }

            while directiveIndex < directives.count, directives[directiveIndex].0 <= start {
                symbols.append(.tag(.instrument(directives[directiveIndex].1)))
                directiveIndex += 1
            }

            for annotation in annotations {
                if case let .mark(time, dynamic) = annotation,
                   time == start,
                   let intensity = convertToGuidoIntensity(dynamic) {
                    symbols.append(.tag(.intensity(intensity)))
                }
            }

            let segmentDuration = BeatDuration(end.numberValue - start.numberValue)
            var tiedToNext = false

            if let event = events.first(where: { $0.attack <= start && $0.end >= end }) {
                tiedToNext = event.end != end
                symbols += try _makeSymbols(pitches: event.pitches, duration: segmentDuration)
            } else {
                symbols += try _makeRestSymbols(duration: segmentDuration)
            }

            if tiedToNext {
                symbols.append(.tag(.tie(GMNTie(span: .end).require())))
            } else if barTimes.contains(end) {
                symbols.append(.tag(.barLine(GMNBarLine(kind: .single))))
            }

            chunks.append((start, symbols))
        }

        return chunks
    }

    private static func _makePartBody(part: Part<BeatTime, Pitch>,
                                      measureCount: UInt,
                                      tempoMap: TempoMap) throws(Guido.Error) -> [GMNSymbol] {
        let events = _events(part.noteTable)
        let directives = _instrumentDirectives(part.instrumentMap)
        let tempos = _tempoDirectives(tempoMap)
        let annotations = _dynamicAnnotations(part.dynamicMap)
        let barTimes = _barTimes(measureCount: measureCount)
        let endTime = BeatTime(Number(numerator: measureCount * 4, denominator: 1))
        let sortedBoundaries = _boundaries(events: events,
                                           directives: directives,
                                           tempos: tempos,
                                           annotations: annotations,
                                           barTimes: barTimes,
                                           endTime: endTime)
        let chunks = try _makeChunks(events: events,
                                     directives: directives,
                                     tempos: tempos,
                                     annotations: annotations,
                                     barTimes: barTimes,
                                     sortedBoundaries: sortedBoundaries)

        var body = _wrapDynamicRamps(chunks: chunks, annotations: annotations)

        body.append(.tag(.barLine(GMNBarLine(kind: .final))))

        return body
    }

    private static func _makeRestSymbols(duration: BeatDuration) throws(Guido.Error) -> [GMNSymbol] {
        guard let length = convertToGuidoDuration(duration)
        else { throw Guido.Error.unrepresentableDuration("\(duration)") }

        return [.rest(GMNRest(duration: length))]
    }

    private static func _makeSymbols(pitches: [Pitch],
                                     duration: BeatDuration) throws(Guido.Error) -> [GMNSymbol] {
        guard let length = convertToGuidoDuration(duration)
        else { throw Guido.Error.unrepresentableDuration("\(duration)") }

        if pitches.count == 1 {
            let pitch = try convertToGuidoPitch(pitches[0])

            return [.note(GMNNote(pitch: pitch, duration: length))]
        }

        var segments: [GMNChord.Segment] = []

        for pitch in pitches {
            let gPitch = try convertToGuidoPitch(pitch)

            guard let segment = GMNChord.Segment(symbols: [.note(GMNNote(pitch: gPitch, duration: length))])
            else { throw Guido.Error.unrepresentableDuration("\(duration)") }

            segments.append(segment)
        }

        guard let chord = GMNChord(segments: segments)
        else { throw Guido.Error.unrepresentableDuration("\(duration)") }

        return [.chord(chord)]
    }

    // Per §3.1.7 of the ABC exporter's own reasoning, `beatTimeRange` is
    // `nil` for a work with nothing in it, and that's still one (empty,
    // rest-filled) measure.
    private static func _measureCount(work: Work) -> UInt {
        guard let range = work.beatTimeRange
        else { return 1 }

        let measures = (range.upperBound.doubleValue / 4).rounded(.up)

        return max(1, UInt(measures))
    }

    private static func _tempoDirectives(_ tempoMap: TempoMap) -> [(BeatTime, GMNTempo)] {
        var directives: [(BeatTime, GMNTempo)] = []

        tempoMap.forEach { _, time, tempo, _ in
            if let gTempo = convertToGuidoTempo(tempo) {
                directives.append((time, gTempo))
            }
        }

        return directives
    }

    // Replaces every run of chunks a ramp annotation covers with one chunk
    // holding a single `\crescendo`/`\diminuendo` tag whose `body` is that
    // run — per the module-wide rule that Guido dynamic ramps are
    // body-scoping, not flat markers. A hairpin alone carries no target
    // level (`GMNDynamicRamp` has only a direction), so an explicit
    // `\intensity` mark is nested at each end, inside the ramp's own span,
    // where `DynamicMap`'s linear interpolation on reimport threads straight
    // through it.
    private static func _wrapDynamicRamps(chunks: [(start: BeatTime, symbols: [GMNSymbol])],
                                          annotations: [DynamicAnnotation]) -> [GMNSymbol] {
        var rampsByStart: [BeatTime: Ramp] = [:]

        for annotation in annotations {
            if case let .ramp(start, startDynamic, end, endDynamic, direction) = annotation {
                rampsByStart[start] = Ramp(direction: direction,
                                           end: end,
                                           endDynamic: endDynamic,
                                           startDynamic: startDynamic)
            }
        }

        var symbols: [GMNSymbol] = []
        var index = 0

        while index < chunks.count {
            let chunk = chunks[index]

            guard let ramp = rampsByStart[chunk.start]
            else {
                symbols += chunk.symbols
                index += 1
                continue
            }

            var body: [GMNSymbol] = []

            if let startMark = convertToGuidoIntensity(ramp.startDynamic) {
                body.append(.tag(.intensity(startMark)))
            }

            while index < chunks.count, chunks[index].start < ramp.end {
                body += chunks[index].symbols
                index += 1
            }

            if let endMark = convertToGuidoIntensity(ramp.endDynamic) {
                body.append(.tag(.intensity(endMark)))
            }

            let dynamicRamp = GMNDynamicRamp(direction: ramp.direction, body: body).require()

            symbols.append(.tag(.dynamicRamp(dynamicRamp)))
        }

        return symbols
    }
}

// MARK: - ExporterProtocol

extension Guido.Exporter: ExporterProtocol {

    // MARK: Internal Instance Properties

    internal var writableFileFormats: [FileFormat] {
        [.gmn]
    }

    // MARK: Internal Instance Methods

    internal func write(works: [Work],
                        as fileFormat: FileFormat) throws(Guido.Error) -> FileWrapper {
        switch fileFormat {
        case .gmn:
            guard !works.isEmpty
            else { throw Guido.Error.noWorksToExport }

            guard let work = works.first,
                  works.count == 1
            else { throw Guido.Error.multipleWorksNotSupported }

            let score = try convert(work)
            let data = try Guido.Formatter().format(score)

            return FileWrapper(regularFileWithContents: data)

        default:
            throw Guido.Error.unsupportedFileFormat(fileFormat.displayName)
        }
    }
}

// MARK: - Sendable

extension Guido.Exporter: Sendable {
}
