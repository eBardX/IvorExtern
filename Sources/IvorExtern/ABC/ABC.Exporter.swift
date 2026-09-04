// © 2025–2026 John Gary Pusey (see LICENSE.md)

internal import Foundation
internal import IvorABC
internal import IvorModel

private import IvorTiming
private import IvorTuning
private import XestiNumbers
private import XestiTools

extension ABC {
    // Not a namespace: `ExporterProtocol`'s instance members live in the
    // following extension, invisible to this check from here.
    // swiftformat:disable:next enumNamespaces
    internal struct Exporter { // swiftlint:disable:this convenience_type

        // MARK: Private Nested Types

        private struct Event {

            // MARK: Fileprivate Instance Properties

            fileprivate let attack: BeatTime
            fileprivate let duration: BeatDuration
            fileprivate var pitches: [IvorTuning.Pitch]

            fileprivate var end: BeatTime {
                BeatTime(attack.numberValue + duration.numberValue)
            }
        }
    }
}

// MARK: -

extension ABC.Exporter {

    // MARK: Internal Instance Methods

    internal func convert(_ work: Work) throws(ABC.Error) -> ABCTune {
        do {
            return try Self._convert(work: work)
        } catch let error as any EnhancedError {
            throw ABC.Error.convertFailure(error)
        } catch {
            throw ABC.Error.convertFailure(nil)
        }
    }

    // MARK: Private Type Methods

    private static func _convert(work: Work) throws(ABC.Error) -> ABCTune {
        guard case let .standardBeat(parts, tempoMap) = work.content
        else {
            guard work.pitchNotation == .standard
            else { throw ABC.Error.unsupportedPitchNotation(work.pitchNotation) }

            throw ABC.Error.unsupportedTimeBasis(work.timeBasis)
        }

        let measureCount = _measureCount(work: work)
        let header = _makeHeader(work: work,
                                 parts: parts,
                                 tempoMap: tempoMap)
        let body = try _makeBody(parts: parts,
                                 measureCount: measureCount)

        guard let tune = ABCTune(header: header,
                                 body: body)
        else { throw ABC.Error.noWorksToExport }

        return tune
    }

    // Reduces a dynamic map's (time, level) entries into decoration
    // placements, per the module-wide positional convention: two entries
    // at the *same* time are an instantaneous step, emitted as a single
    // mark using the post-jump level; two entries at *different* times are
    // a ramp, emitted as a `!crescendo(!`/`!crescendo)!` (or diminuendo)
    // hairpin pair spanning them. A trailing unpaired entry gets a plain
    // mark. Only the ten standard levels convert to a decoration name (see
    // `convertToABCDecorationName(_:)`); anything else is silently dropped
    // rather than rounded to the nearest one.
    private static func _dynamicAnnotations(_ dynamicMap: DynamicMap<BeatTime>) -> [BeatTime: [ABCDecoration.Name]] {
        guard !dynamicMap.isEmpty
        else { return [:] }

        var entries: [(BeatTime, Dynamic)] = []

        dynamicMap.forEach { _, time, dynamic, _ in entries.append((time, dynamic)) }

        var annotations: [BeatTime: [ABCDecoration.Name]] = [:]
        var index = 0

        while index < entries.count {
            let (time, dynamic) = entries[index]

            if index + 1 < entries.count, entries[index + 1].0 == time {
                let (_, nextDynamic) = entries[index + 1]

                if let name = convertToABCDecorationName(nextDynamic) {
                    annotations[time, default: []].append(name)
                }

                index += 2
            } else if index + 1 < entries.count {
                let (endTime, endDynamic) = entries[index + 1]
                let direction = endDynamic > dynamic ? "crescendo" : "diminuendo"

                if let openName = ABCDecoration.Name(stringValue: direction + "("),
                   let closeName = ABCDecoration.Name(stringValue: direction + ")") {
                    annotations[time, default: []].append(openName)
                    annotations[endTime, default: []].append(closeName)
                }

                index += 2
            } else {
                if let name = convertToABCDecorationName(dynamic) {
                    annotations[time, default: []].append(name)
                }

                index += 1
            }
        }

        return annotations
    }

    // Every note table entry is walked once, in time order. Consecutive
    // entries sharing an attack time and a duration are a chord (§4.17);
    // anything else stays a separate event. Ending pitch is dropped — a
    // glissando exports at its start pitch, per the module-wide rule.
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

    private static func _instrumentDirectives(_ instrumentMap: InstrumentMap<BeatTime>) -> [(BeatTime, ABCDirective)] {
        var directives: [(BeatTime, ABCDirective)] = []
        let name = ABCDirective.Name(stringValue: "MIDI").require()

        instrumentMap.forEach { _, time, instrument, _ in
            guard let program = generalMIDIProgramNumber(name: instrument.stringValue)
            else { return }

            directives.append((time, ABCDirective(name: name,
                                                  value: "program \(program)")))
        }

        return directives
    }

    // A non-power-of-2 denominator has no plain ABC spelling (`ABCLength`
    // requires one), so the odd factor left after removing every factor of
    // 2 becomes the tuplet's `noteCount`, always paired with an explicit
    // `beatCount` of 2 chosen by this exporter — since both the tuplet
    // marker and the written length it precedes are emitted together here,
    // there's no need to match ABC's own note-count-keyed default beat
    // count table (§4.13); only internal consistency with the written
    // length below matters. `affectedCount` is always 1: every event gets
    // its own tuplet marker rather than trying to merge a run of equal
    // durations into one grouped marker, so a chord and a following single
    // note each scale independently even when they'd share a marker in
    // idiomatic hand-written ABC.
    private static func _lengthAndTuplet(for duration: BeatDuration) throws(ABC.Error) -> (length: ABCLength, tuplet: ABCTuplet?) {
        let numberValue = duration.numberValue

        guard numberValue.isRational
        else { throw ABC.Error.unrepresentableDuration("\(duration)") }

        let numerator = numberValue.numerator.uintValue
        let denominator = numberValue.denominator.uintValue

        guard numerator > 0
        else { throw ABC.Error.unrepresentableDuration("\(duration)") }

        var oddPart = denominator

        while oddPart.isMultiple(of: 2) {
            oddPart /= 2
        }

        if oddPart == 1 {
            guard let length = ABCLength(numerator: numerator,
                                         denominator: denominator)
            else { throw ABC.Error.unrepresentableDuration("\(duration)") }

            return (length, nil)
        }

        guard (2...9).contains(oddPart),
              let tuplet = ABCTuplet(noteCount: oddPart,
                                     beatCount: 2,
                                     affectedCount: 1)
        else { throw ABC.Error.unrepresentableDuration("\(duration)") }

        // `ABCLength.init?` requires the *raw* denominator it's given to
        // already be a power of 2 — it validates before reducing, so a
        // denominator that would only become one after gcd reduction still
        // fails. Written length = duration × noteCount / beatCount =
        // (numerator / (oddPart × pow2Part)) × (oddPart / 2); the `oddPart`
        // introduced by the tuplet scale exactly cancels the one just
        // divided out of `denominator`, leaving `numerator` unchanged over
        // a denominator of `pow2Part × 2` — already a power of 2 by
        // construction, with no reduction required.
        let pow2Part = denominator / oddPart

        guard let length = ABCLength(numerator: numerator,
                                     denominator: pow2Part * 2)
        else { throw ABC.Error.unrepresentableDuration("\(duration)") }

        return (length, tuplet)
    }

    private static func _makeBody(parts: [Part<BeatTime, Pitch>],
                                  measureCount: UInt) throws(ABC.Error) -> [ABCBodyEntry] {
        var body: [ABCBodyEntry] = []
        let needsVoiceFields = _needsVoiceFields(parts: parts)

        for index in parts.indices {
            if needsVoiceFields {
                body.append(.field(.voice(ABCVoice(id: _voiceID(index: index)).require())))
            }

            body += try _makePartBody(part: parts[index],
                                      measureCount: measureCount)
        }

        return body
    }

    private static func _makeHeader(work: Work,
                                    parts: [Part<BeatTime, Pitch>],
                                    tempoMap: TempoMap) -> [ABCHeaderEntry] {
        var header: [ABCHeaderEntry] = [.field(.referenceNumber(ABCReferenceNumber(uintValue: 1).require())),
                                        .field(.tuneTitle(ABCText(stringValue: work.name).require())),
                                        .field(.meter(.standard(ABCTimeSignature.StandardMeter(numerator: 4,
                                                                                               denominator: 4).require()))),
                                        .field(.unitNoteLength(ABCLength(numerator: 1,
                                                                         denominator: 4).require()))]

        if let tempo = convertToABCTempo(tempoMap[.zero]) {
            header.append(.field(.tempo(tempo)))
        }

        if _needsVoiceFields(parts: parts) {
            for index in parts.indices {
                header.append(.field(.voice(_makeVoice(part: parts[index],
                                                       index: index))))
            }
        }

        // K:C, spelling every altered pitch class with an explicit
        // accidental in the body — the model doesn't preserve the
        // originating key, and `Pitch` already carries its spelling
        // directly, so this is correctness-preserving rather than merely
        // a conservative default.
        header.append(.field(.key(.standard(ABCKeySignature.Standard(tonic: .c,
                                                                     mode: .major).require()))))

        return header
    }

    // Lays one part's notes onto the fixed 4/4 grid: a note or chord
    // crossing a barline splits into tied segments (each independently
    // tuplet-scaled), gaps become rests, and every measure sums to exactly
    // 4 beats. See `_lengthAndTuplet(for:)` for how a non-power-of-2
    // duration becomes a tuplet-marked segment instead.
    private static func _makePartBody(part: Part<BeatTime, Pitch>,
                                      measureCount: UInt) throws(ABC.Error) -> [ABCBodyEntry] {
        let events = _events(part.noteTable)
        let annotations = _dynamicAnnotations(part.dynamicMap)
        let directives = _instrumentDirectives(part.instrumentMap)
        let endTime = BeatTime(Number(numerator: measureCount * 4, denominator: 1))

        var barTimes: [BeatTime] = []
        var barBeat: UInt = 4

        while barBeat < measureCount * 4 {
            barTimes.append(BeatTime(Number(numerator: barBeat, denominator: 1)))
            barBeat += 4
        }

        var boundaries: Set<BeatTime> = [.zero, endTime]

        for barTime in barTimes {
            boundaries.insert(barTime)
        }

        for event in events {
            boundaries.insert(event.attack)
            boundaries.insert(event.end)
        }

        let sortedBoundaries = boundaries.sorted()
        var entries: [ABCBodyEntry] = []
        var pending: [ABCSymbol] = []
        var directiveIndex = 0

        func flush() {
            guard !pending.isEmpty
            else { return }

            entries.append(.symbols(pending))
            pending = []
        }

        for index in 0..<(sortedBoundaries.count - 1) {
            let start = sortedBoundaries[index]
            let end = sortedBoundaries[index + 1]

            guard start < end
            else { continue }

            while directiveIndex < directives.count,
                  directives[directiveIndex].0 <= start {
                flush()
                entries.append(.directive(directives[directiveIndex].1))
                directiveIndex += 1
            }

            for name in annotations[start] ?? [] {
                guard let decoration = ABCDecoration(name: name)
                else { continue }

                pending.append(.decoration(decoration))
            }

            let segmentDuration = BeatDuration(end.numberValue - start.numberValue)

            if let event = events.first(where: { $0.attack <= start && $0.end >= end }) {
                let isLastSegment = event.end == end

                pending += try _makeSymbols(pitches: event.pitches,
                                            duration: segmentDuration,
                                            tie: !isLastSegment)
            } else {
                pending += try _makeRestSymbols(duration: segmentDuration)
            }

            if barTimes.contains(end) {
                pending.append(.barLine(ABCBarLine(kind: .standard).require()))
            }
        }

        pending.append(.barLine(ABCBarLine(kind: .end).require()))
        flush()

        return entries
    }

    // A rest never carries a tie, so a tuplet-scaled rest segment simply
    // emits its (optional) tuplet marker followed by the rest itself.
    private static func _makeRestSymbols(duration: BeatDuration) throws(ABC.Error) -> [ABCSymbol] {
        let (length, tuplet) = try _lengthAndTuplet(for: duration)
        var symbols: [ABCSymbol] = []

        if let tuplet {
            symbols.append(.tuplet(tuplet))
        }

        symbols.append(.rest(.regular(false, length)))

        return symbols
    }

    // `tie` is `true` when this segment is not the last piece of a note or
    // chord split across a barline — see `_makePartBody(part:measureCount:)`.
    private static func _makeSymbols(pitches: [Pitch],
                                     duration: BeatDuration,
                                     tie: Bool) throws(ABC.Error) -> [ABCSymbol] {
        let (length, tuplet) = try _lengthAndTuplet(for: duration)
        var symbols: [ABCSymbol] = []

        if let tuplet {
            symbols.append(.tuplet(tuplet))
        }

        let tieValue: ABCTie? = tie ? .regular : nil

        if pitches.count == 1 {
            try symbols.append(.note(ABCNote(pitch: convertToABCPitch(pitches[0]),
                                             length: length,
                                             tie: tieValue)))
        } else {
            let unitLength = ABCLength(numerator: 1,
                                       denominator: 1).require()
            var notes: [ABCNote] = []

            for pitch in pitches {
                try notes.append(ABCNote(pitch: convertToABCPitch(pitch),
                                         length: unitLength,
                                         tie: tieValue))
            }

            guard let chord = ABCChord(notes: notes,
                                       length: length,
                                       tie: tieValue)
            else { throw ABC.Error.unrepresentableDuration("\(duration)") }

            symbols.append(.chord(chord))
        }

        return symbols
    }

    // A single, unnamed part is written as an implicit voice — no `V:`
    // field at all — matching how a real single-voice ABC tune is normally
    // written, and keeping that case round-trip-safe: an implicit voice
    // imports back as unnamed (see `ABCFunctions.determinePartName`), while
    // an explicit `V:` field's `id` becomes the imported name whenever it
    // has no name property of its own. A lone *named* part still needs its
    // `V:` field, since that's ABC's only place to record a part name.
    private static func _needsVoiceFields(parts: [Part<BeatTime, Pitch>]) -> Bool {
        parts.count > 1 || parts.first.map { !$0.name.isEmpty } ?? false
    }

    private static func _makeVoice(part: Part<BeatTime, Pitch>,
                                   index: Int) -> ABCVoice {
        var properties: [String: String] = [:]

        if !part.name.isEmpty {
            properties["name"] = part.name
        }

        return ABCVoice(id: _voiceID(index: index),
                        properties: properties).require()
    }

    // Per §3.1.7, `M:4/4` combined with `L:1/4` puts exactly 4 beats per
    // measure; `beatTimeRange` is `nil` for a work with nothing in it, and
    // that's still one (empty, rest-filled) measure.
    private static func _measureCount(work: Work) -> UInt {
        guard let range = work.beatTimeRange
        else { return 1 }

        let measures = (range.upperBound.doubleValue / 4).rounded(.up)

        return max(1, UInt(measures))
    }

    private static func _voiceID(index: Int) -> ABCVoice.ID {
        ABCVoice.ID(stringValue: "V\(index + 1)").require()
    }
}

// MARK: - ExporterProtocol

extension ABC.Exporter: ExporterProtocol {

    // MARK: Internal Instance Properties

    internal var writableFileFormats: [FileFormat] {
        [.abc]
    }

    // MARK: Internal Instance Methods

    // ABC is the one 1:N format — a tunebook holds many tunes — so, unlike
    // every other exporter in this module, `works` is never restricted to
    // exactly one.
    internal func write(works: [Work],
                        as fileFormat: FileFormat) throws(ABC.Error) -> FileWrapper {
        switch fileFormat {
        case .abc:
            guard !works.isEmpty
            else { throw ABC.Error.noWorksToExport }

            let tunes = try works.map(convert)

            guard let tunebook = ABCTunebook(fileHeader: [],
                                             tunes: tunes)
            else { throw ABC.Error.noWorksToExport }

            let data = try ABC.Formatter().format(tunebook)

            return FileWrapper(regularFileWithContents: data)

        default:
            throw ABC.Error.unsupportedFileFormat(fileFormat.displayName)
        }
    }
}

// MARK: - Sendable

extension ABC.Exporter: Sendable {
}
