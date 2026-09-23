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
            case mark(time: BeatTime, dynamic: Dynamic, mark: String?)
            case ramp(start: BeatTime, startDynamic: Dynamic, end: BeatTime, endDynamic: Dynamic, direction: GMNDynamicRamp.Direction)
        }

        private struct Event {

            // MARK: Fileprivate Instance Properties

            fileprivate let attack: BeatTime
            fileprivate let duration: BeatDuration
            fileprivate var extrasList: [Extras?]
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
            case let .mark(time, _, _):
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

        var entries: [(time: BeatTime, dynamic: Dynamic, mark: String?)] = []

        dynamicMap.forEach { _, time, dynamic, extras in
            entries.append((time, dynamic, stringValue(extras, .dynamicMark)))
        }

        var annotations: [DynamicAnnotation] = []
        var index = 0

        while index < entries.count {
            let (time, dynamic, mark) = entries[index]

            if index + 1 < entries.count, entries[index + 1].time == time {
                let (_, nextDynamic, nextMark) = entries[index + 1]

                annotations.append(.mark(time: time, dynamic: nextDynamic, mark: nextMark))
                index += 2
            } else if index + 1 < entries.count {
                let (endTime, endDynamic, _) = entries[index + 1]
                let direction: GMNDynamicRamp.Direction = endDynamic > dynamic ? .crescendo : .diminuendo

                annotations.append(.ramp(start: time,
                                         startDynamic: dynamic,
                                         end: endTime,
                                         endDynamic: endDynamic,
                                         direction: direction))
                index += 2
            } else {
                annotations.append(.mark(time: time, dynamic: dynamic, mark: mark))
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

        noteTable.forEach { _, attack, duration, startPitch, _, extras in
            if let last = events.last,
               last.attack == attack,
               last.duration == duration {
                events[events.count - 1].pitches.append(startPitch)
                events[events.count - 1].extrasList.append(extras)
            } else {
                events.append(Event(attack: attack,
                                    duration: duration,
                                    extrasList: [extras],
                                    pitches: [startPitch]))
            }
        }

        return events
    }

    private static func _instrumentDirectives(_ instrumentMap: InstrumentMap<BeatTime>) -> [(BeatTime, GMNInstrument)] {
        var directives: [(BeatTime, GMNInstrument)] = []

        instrumentMap.forEach { _, time, instrument, extras in
            let midi = intValue(extras, .midiProgram).map { $0 - 1 } ?? generalMIDIProgramNumber(name: instrument.stringValue)

            directives.append((time, GMNInstrument(name: instrument.stringValue, midi: midi)))
        }

        return directives
    }

    // The `\intensity` tag one `.mark` annotation at `start` should emit, if
    // any — a literal `dynamicMark` when the entry carried one, otherwise the
    // numeric-level conversion. `nil` for a `.ramp` annotation (ramps are
    // handled by `_wrapDynamicRamps` instead) or a `.mark` at a different
    // time, and for either a mark or a level with no `GMNIntensity`
    // equivalent.
    private static func _intensity(for annotation: DynamicAnnotation, at start: BeatTime) -> GMNIntensity? {
        guard case let .mark(time, dynamic, mark) = annotation,
              time == start
        else { return nil }

        if let mark {
            return GMNIntensity(type: mark)
        }

        return convertToGuidoIntensity(dynamic)
    }

    // A `\slurBegin:n` marker, written immediately before a note/chord's
    // own symbol(s) (and any articulation wrapping above) — only called
    // for an event's *first* segment. A `slurStart` extra with no
    // parseable `.string` id (e.g. one that originated from ABC's bare-flag
    // convention, carried across a cross-format conversion) is dropped
    // rather than guessed at: Guido's own slur pairing is ident-based, not
    // stack-based, so there's no positional fallback the way ABC's own
    // export has.
    private static func _leadingSlurStartSymbols(_ extrasList: [Extras?]) -> [GMNSymbol] {
        guard let idText = _unionElements(extrasList).first(where: { $0.name == Extra.slurStart.name }),
              case let .string(text)? = idText.values.first,
              let uintValue = UInt(text),
              let ident = GMNTag.Ident(uintValue: uintValue),
              let slur = GMNSlur(ident: ident, span: .begin)
        else { return [] }

        return [.tag(.slur(slur))]
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
            // when there's nothing to preserve. Neither does a positional
            // "Voice N" fallback name: re-import regenerates it from
            // position, whereas writing it would come back as a spurious
            // "Voice N" instrument.
            if !parts[index].name.isEmpty,
               !isFallbackPartName(parts[index].name, index: index, count: parts.count) {
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
                if let intensity = _intensity(for: annotation, at: start) {
                    symbols.append(.tag(.intensity(intensity)))
                }
            }

            let segmentDuration = BeatDuration(end.numberValue - start.numberValue)
            var tiedToNext = false

            if let event = events.first(where: { $0.attack <= start && $0.end >= end }) {
                tiedToNext = event.end != end
                symbols += try _segmentSymbols(event: event, start: start, end: end, duration: segmentDuration)
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

    // One event's own segment symbols: articulation-wrapped note/chord
    // symbols, with a leading `\slurBegin:n` on the event's first segment
    // and a trailing `\slurEnd:n` on its last.
    private static func _segmentSymbols(event: Event,
                                        start: BeatTime,
                                        end: BeatTime,
                                        duration: BeatDuration) throws(Guido.Error) -> [GMNSymbol] {
        var symbols: [GMNSymbol] = []
        var noteSymbols = try _makeSymbols(pitches: event.pitches, duration: duration)

        if event.attack == start {
            noteSymbols = _wrapArticulations(noteSymbols, event.extrasList)
            symbols += _leadingSlurStartSymbols(event.extrasList)
        }

        symbols += noteSymbols

        if event.end == end {
            symbols += _trailingSlurEndSymbols(event.extrasList)
        }

        return symbols
    }

    private static func _tempoDirectives(_ tempoMap: TempoMap) -> [(BeatTime, GMNTempo)] {
        var directives: [(BeatTime, GMNTempo)] = []

        tempoMap.forEach { _, time, tempo, extras in
            if let gTempo = convertToGuidoTempo(tempo, text: stringValue(extras, .tempoText)) {
                directives.append((time, gTempo))
            }
        }

        return directives
    }

    // A `\slurEnd:n` marker, written immediately after a note/chord's own
    // symbol(s) — only called for an event's *last* segment. Same id-only
    // requirement as `_leadingArticulationSymbols(_:)`.
    private static func _trailingSlurEndSymbols(_ extrasList: [Extras?]) -> [GMNSymbol] {
        guard let idText = _unionElements(extrasList).first(where: { $0.name == Extra.slurEnd.name }),
              case let .string(text)? = idText.values.first,
              let uintValue = UInt(text),
              let ident = GMNTag.Ident(uintValue: uintValue),
              let slur = GMNSlur(ident: ident, span: .end)
        else { return [] }

        return [.tag(.slur(slur))]
    }

    // See `ABC.Exporter._unionElements(_:)` — same chord-wide-union
    // simplification, for the same reason (Guido's own tags apply to a
    // whole chord group, not one member note).
    private static func _unionElements(_ extrasList: [Extras?]) -> [Extra] {
        extrasList.compactMap { $0?.elements }.flatMap { $0 }
    }

    // Wraps `symbols` (the event's own note/chord symbol(s)) one layer per
    // Tier 1/fingering/breathMark extra present, innermost-first — only
    // called for an event's *first* segment (a tie-continuation's own
    // segments carry no repeated wrapping). `body:`-form tags are the only
    // shape guidolib's own template gives most of these kinds — see
    // `convertToGuidoTag(_:body:)`.
    private static func _wrapArticulations(_ symbols: [GMNSymbol], _ extrasList: [Extras?]) -> [GMNSymbol] {
        _unionElements(extrasList).reduce(symbols) { wrapped, element in
            guard let tag = convertToGuidoTag(element, body: wrapped)
            else { return wrapped }

            return [.tag(tag)]
        }
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
