// © 2025–2026 John Gary Pusey (see LICENSE.md)

internal import Foundation
internal import IvorModel
internal import IvorMusicXML

private import IvorTiming
private import IvorTuning
private import XestiNumbers
private import XestiTools

extension MusicXML {
    // Not a namespace: `ExporterProtocol`'s instance members live in the
    // following extension, invisible to this check from here.
    // swiftformat:disable:next enumNamespaces
    internal struct Exporter { // swiftlint:disable:this convenience_type

        // MARK: Private Nested Types

        private enum DynamicAnnotation {
            case mark(time: BeatTime, dynamic: Dynamic, mark: String?)
            case ramp(start: BeatTime, startDynamic: Dynamic, end: BeatTime, endDynamic: Dynamic, kind: MXLWedge.Kind)
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

            fileprivate let end: BeatTime
            fileprivate let endDynamic: Dynamic
            fileprivate let kind: MXLWedge.Kind
            fileprivate let startDynamic: Dynamic
        }
    }
}

// MARK: -

extension MusicXML.Exporter {

    // MARK: Internal Instance Methods

    internal func convert(_ work: Work) throws(MusicXML.Error) -> MusicXML.Score {
        do {
            return try Self._convert(work: work)
        } catch let error as any EnhancedError {
            throw MusicXML.Error.convertFailure(error)
        } catch {
            throw MusicXML.Error.convertFailure(nil)
        }
    }

    // MARK: Private Type Properties

    // `MXLPositiveDivisions` is a positive integer, so every onset and
    // duration in the work has to land on one exactly. This is the ceiling on
    // how fine that grid is allowed to get, matched to what
    // `MXLValidator`/most real-world readers expect (720 divisions per
    // quarter note is already finer than any conventional written rhythm
    // needs); past it, durations round to the nearest division instead of
    // enlarging the grid further.
    private static let maxDivisions = 30_240

    // MARK: Private Type Methods

    // Every 4-beat measure boundary strictly between the start and the end of
    // the work — `.zero` and the final bound are supplied separately by
    // `_boundaries(events:tempos:pans:annotations:barTimes:endTime:)`.
    private static func _barTimes(measureCount: UInt) -> [BeatTime] {
        var barTimes: [BeatTime] = []
        var barBeat: UInt = 4

        while barBeat < measureCount * 4 {
            barTimes.append(BeatTime(Number(numerator: barBeat, denominator: 1)))
            barBeat += 4
        }

        return barTimes
    }

    // The sorted union of every time this part's body needs to notice:
    // `.zero` and the work's end, every bar line, every note's attack and
    // end, and every tempo/pan/dynamic annotation's own time. Splitting a
    // note at one of these — even one with no note of its own — is what lets
    // a tempo change, pan change, or dynamic mark/wedge boundary land exactly
    // where the model says it should, and what lets a note crossing a bar
    // line split into per-measure, tied segments.
    private static func _boundaries(events: [Event],
                                    tempos: [(BeatTime, Tempo)],
                                    pans: [(BeatTime, Pan, Double?)],
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

        for (time, _) in tempos {
            boundaries.insert(time)
        }

        for (time, _, _) in pans {
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

    private static func _convert(work: Work) throws(MusicXML.Error) -> MusicXML.Score {
        guard case let .standardBeat(parts, tempoMap) = work.content
        else {
            guard work.pitchNotation == .standard
            else { throw MusicXML.Error.unsupportedPitchNotation(work.pitchNotation) }

            throw MusicXML.Error.unsupportedTimeBasis(work.timeBasis)
        }

        let measureCount = _measureCount(work: work)
        let divisions = _divisions(parts: parts, tempoMap: tempoMap)

        var scoreParts: [MusicXML.ScorePart] = []
        var xmlParts: [MusicXML.Score.Part] = []

        for (index, part) in parts.enumerated() {
            let id = "P\(index + 1)"

            scoreParts.append(_makeScorePart(id: id, part: part))
            try xmlParts.append(MusicXML.Score.Part(id: id,
                                                    measures: _makePartBody(part: part,
                                                                            index: index,
                                                                            measureCount: measureCount,
                                                                            divisions: divisions,
                                                                            tempoMap: tempoMap)))
        }

        return MusicXML.Score(movementTitle: work.name.nilIfEmpty,
                              partList: MXLPartList(items: scoreParts.map { .scorePart($0) }),
                              parts: xmlParts)
    }

    // Computes the finest resolution (divisions per quarter note) needed to
    // land every attack, duration, and tempo-change time in the work exactly
    // on an integer division, as the least common multiple of their rational
    // denominators — capped at `maxDivisions`, past which
    // `convertToMusicXMLDivisions(_:_:)` rounds instead.
    private static func _divisions(parts: [Part<BeatTime, Pitch>],
                                   tempoMap: TempoMap) -> Int {
        var result = Number(1)

        func fold(_ value: Number) {
            guard value.isRational
            else { return }

            result = lcm(result, value.denominator)
        }

        for part in parts {
            part.noteTable.forEach { _, attack, duration, _, _, _ in
                fold(attack.numberValue)
                fold(duration.numberValue)
            }
        }

        tempoMap.forEach { _, time, _, _ in fold(time.numberValue) }

        return max(1, min(result.intValue, maxDivisions))
    }

    // Reduces a dynamic map's (time, level) entries into mark/ramp
    // annotations, per the module-wide positional convention: two entries at
    // the *same* time are an instantaneous step, emitted as a single
    // `<dynamics>` mark using the post-jump level; two entries at *different*
    // times are a ramp, emitted as a `<wedge>`. A trailing unpaired entry
    // gets a plain mark.
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
                let kind: MXLWedge.Kind = endDynamic > dynamic ? .crescendo : .diminuendo

                annotations.append(.ramp(start: time,
                                         startDynamic: dynamic,
                                         end: endTime,
                                         endDynamic: endDynamic,
                                         kind: kind))
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

    // The earliest `InstrumentMap` entry only. A `<score-part>` carries at
    // most one static `<score-instrument>`/`<midi-instrument>` pair, so a
    // mid-piece instrument change (unlike a mid-piece tempo, pan, or dynamic
    // change, all of which have a `<direction>`/`<sound>` home mid-measure)
    // has no lossless home in this exporter and is dropped after the first
    // entry.
    private static func _firstInstrument(_ instrumentMap: InstrumentMap<BeatTime>) -> (instrument: Instrument, extras: Extras?)? {
        var first: (instrument: Instrument, extras: Extras?)?

        instrumentMap.forEach { _, _, instrument, extras in
            if first == nil {
                first = (instrument, extras)
            }
        }

        return first
    }

    // The earliest `PanMap` entry's extras only, for the one datum MusicXML
    // declares statically per part rather than mid-measure: elevation. Pan
    // itself needs no such lookup — every entry becomes its own
    // `<direction>`/`<sound pan="...">` in `_panDirectives`.
    private static func _firstPanExtras(_ panMap: PanMap<BeatTime>) -> Extras? {
        var first: Extras?
        var found = false

        panMap.forEach { _, _, _, extras in
            if !found {
                found = true
                first = extras
            }
        }

        return first
    }

    // Bins the flat, boundary-ordered stream of music items into one
    // `Measure` per 4-beat span, prepending `<attributes>` (divisions, a
    // fixed 4/4 time signature, and a fixed C-major key signature — the model
    // has no field for either) to the first measure only, per
    // `MXLValidator`'s `durationBeforeDivisions` check.
    private static func _groupIntoMeasures(chunks: [(start: BeatTime, items: [MXLMusicItem])],
                                           measureCount: UInt,
                                           divisions: Int) -> [MusicXML.Score.Part.Measure] {
        var itemsByMeasure: [Int: [MXLMusicItem]] = [:]

        for chunk in chunks {
            let index = Int(chunk.start.doubleValue / 4)

            itemsByMeasure[index, default: []] += chunk.items
        }

        var measures: [MusicXML.Score.Part.Measure] = []

        for index in 0..<Int(measureCount) {
            var items = itemsByMeasure[index] ?? []

            if index == 0 {
                items = [.attributes(_makeAttributes(divisions: divisions))] + items
            }

            measures.append(MusicXML.Score.Part.Measure(number: String(index + 1), items: items))
        }

        return measures
    }

    private static func _makeAttributes(divisions: Int) -> MXLAttributes {
        MXLAttributes(divisions: MXLPositiveDivisions(intValue: divisions).require(),
                      key: [MXLKey(content: .traditionalKey(MXLTraditionalKey(fifths: MXLFifths(intValue: 0).require())))],
                      time: [MXLTime(content: .timeSignature([MXLTimeSignature(beats: "4", beatType: "4")], interchangeable: nil))],
                      content: .transpose([]))
    }

    // One chunk per boundary interval, each either a tied note/chord fragment
    // or a rest, with any tempo/pan/dynamics `<direction>` scheduled at its
    // own start folded in ahead of it. Dynamics travel exclusively through
    // `<direction>` marks and `<wedge>` hairpins here, never through a note's
    // own `dynamics` attribute: `MusicXML.Importer`'s
    // `_convert(part:panMap:directionDynamicMap:)` lets the *first* note-level
    // velocity found in a voice pre-empt its shared direction-level dynamic
    // map entirely, so mixing the two channels would silently drop every
    // direction-level mark once any one note carried its own velocity.
    private static func _makeChunks(events: [Event],
                                    tempos: [(BeatTime, Tempo)],
                                    pans: [(BeatTime, Pan, Double?)],
                                    annotations: [DynamicAnnotation],
                                    sortedBoundaries: [BeatTime],
                                    divisions: Int) throws(MusicXML.Error) -> [(start: BeatTime, items: [MXLMusicItem])] {
        var chunks: [(start: BeatTime, items: [MXLMusicItem])] = []
        var tempoIndex = 0
        var panIndex = 0
        var ramps: [BeatTime: Ramp] = [:]

        for annotation in annotations {
            if case let .ramp(start, startDynamic, end, endDynamic, kind) = annotation {
                ramps[start] = Ramp(end: end, endDynamic: endDynamic, kind: kind, startDynamic: startDynamic)
            }
        }

        for index in 0..<(sortedBoundaries.count - 1) {
            let start = sortedBoundaries[index]
            let end = sortedBoundaries[index + 1]

            guard start < end
            else { continue }

            var items = _makeDirectionItems(at: start,
                                            tempos: tempos,
                                            tempoIndex: &tempoIndex,
                                            pans: pans,
                                            panIndex: &panIndex,
                                            annotations: annotations,
                                            ramps: ramps)

            items += try _makeSegmentItems(events: events, start: start, end: end, divisions: divisions)

            chunks.append((start, items))
        }

        return chunks
    }

    // The `<direction>` items (tempo, pan, dynamics marks, wedge
    // start/stop) scheduled at one boundary's own start, folded in ahead of
    // that boundary's note or rest.
    private static func _makeDirectionItems(at start: BeatTime,
                                            tempos: [(BeatTime, Tempo)],
                                            tempoIndex: inout Int,
                                            pans: [(BeatTime, Pan, Double?)],
                                            panIndex: inout Int,
                                            annotations: [DynamicAnnotation],
                                            ramps: [BeatTime: Ramp]) -> [MXLMusicItem] {
        var items: [MXLMusicItem] = []

        while tempoIndex < tempos.count, tempos[tempoIndex].0 <= start {
            items.append(.direction(_makeSoundDirection(convertToMusicXMLSound(tempo: tempos[tempoIndex].1))))
            tempoIndex += 1
        }

        while panIndex < pans.count, pans[panIndex].0 <= start {
            items.append(.direction(_makeSoundDirection(convertToMusicXMLSound(pan: pans[panIndex].1,
                                                                               degree: pans[panIndex].2))))
            panIndex += 1
        }

        for annotation in annotations {
            guard case let .mark(time, dynamic, mark) = annotation,
                  time == start
            else { continue }

            if let mark {
                items.append(.direction(_makeDynamicsDirection(convertToMusicXMLDynamics(mark: mark))))
            } else if let item = convertToMusicXMLDynamics(dynamic) {
                items.append(.direction(_makeDynamicsDirection(item)))
            }
        }

        if let ramp = ramps[start] {
            items.append(_makeWedgeDirection(kind: ramp.kind, dynamic: ramp.startDynamic))
        }

        if let ramp = ramps.values.first(where: { $0.end == start }) {
            items.append(_makeWedgeDirection(kind: .stop, dynamic: ramp.endDynamic))
        }

        return items
    }

    // The note/chord or rest item(s) covering one boundary interval.
    private static func _makeDynamicsDirection(_ item: MXLDynamics.Item) -> MXLDirection {
        MXLDirection(kind: [MXLDirection.Kind(content: .dynamics([MXLDynamics(items: [item])]))])
    }

    // One `<note>` per pitch — the first carrying `isChord: false`, every
    // later one `isChord: true`, per the MusicXML convention that a chord's
    // duration and tie state is repeated on each of its notes even though
    // only the first one advances the musical position within the measure.
    // Both the sound tie (`MXLTie`, inside `content`) and the notated tie
    // (`MXLTied`, inside `notations`) are written together, since MusicXML
    // keeps the two independent and an importer or renderer may read either.
    // `extrasList` (per-pitch, parallel to the pitches this event's
    // segments share) only contributes articulation/ornament/technical/
    // fingering items on the segment where `isFirstSegment` is true (a
    // tied-from-previous continuation never repeats them) and a
    // `slurStart`/`slurEnd` item on whichever of `isFirstSegment`/
    // `isLastSegment` matches — the same first/last-segment gating
    // `ABC.Exporter`/`Guido.Exporter` use, adapted to MusicXML's one-
    // `<notations>`-block-per-note shape instead of a symbol stream.
    // Every pitch in a chord shares the same union of markers — see
    // `ABC.Exporter._unionElements(_:)` for why a chord-wide union, not a
    // per-pitch split, is this vocabulary's accepted chord simplification.
    private static func _makeNoteItems(pitches: [Pitch],
                                       duration: MXLPositiveDivisions,
                                       tiedFromPrevious: Bool,
                                       tiedToNext: Bool,
                                       extrasList: [Extras?],
                                       isFirstSegment: Bool,
                                       isLastSegment: Bool) throws(MusicXML.Error) -> [MXLMusicItem] {
        var items: [MXLMusicItem] = []
        let elements = extrasList.compactMap { $0?.elements }.flatMap { $0 }

        for (index, pitch) in pitches.enumerated() {
            let mxlPitch = try convertToMusicXMLPitch(pitch)

            var ties: [MXLTie] = []
            var notationItems: [MXLNotations.Item] = []

            if tiedFromPrevious {
                ties.append(MXLTie(kind: .stop))
                notationItems.append(.tied(MXLTied(kind: .stop)))
            }

            if tiedToNext {
                ties.append(MXLTie(kind: .start))
                notationItems.append(.tied(MXLTied(kind: .start)))
            }

            if isFirstSegment {
                notationItems += convertToMusicXMLNotationItems(elements)
                notationItems += convertToMusicXMLSlurStartItems(elements)
            }

            if isLastSegment {
                notationItems += convertToMusicXMLSlurEndItems(elements)
            }

            let note = MXLNote(content: .regularNote(fullNote: MXLFullNote(isChord: index > 0, content: .pitch(mxlPitch)),
                                                     duration: duration,
                                                     tie: ties),
                               notations: notationItems.isEmpty ? [] : [MXLNotations(items: notationItems)])

            items.append(.note(note))
        }

        return items
    }

    // Lays one part's notes onto the fixed 4/4 grid synthesized across all
    // of this module's exporters — the model carries no time
    // signature — with a note crossing a measure boundary split into tied
    // segments and gaps rest-filled. Tempo is score-wide, not per-part, but
    // `MusicXML.Importer` flattens every part's tempo events into one
    // `TempoMap` (`results.flatMap(\.tempoEvents)`), so only the first part
    // carries it; pan, like the model's own `PanMap`, is per-part.
    private static func _makePartBody(part: Part<BeatTime, Pitch>,
                                      index: Int,
                                      measureCount: UInt,
                                      divisions: Int,
                                      tempoMap: TempoMap) throws(MusicXML.Error) -> [MusicXML.Score.Part.Measure] {
        let events = _events(part.noteTable)
        let annotations = _dynamicAnnotations(part.dynamicMap)
        let pans = _panDirectives(part.panMap)
        let tempos = index == 0 ? _tempoDirectives(tempoMap) : []
        let barTimes = _barTimes(measureCount: measureCount)
        let endTime = BeatTime(Number(numerator: measureCount * 4, denominator: 1))
        let sortedBoundaries = _boundaries(events: events,
                                           tempos: tempos,
                                           pans: pans,
                                           annotations: annotations,
                                           barTimes: barTimes,
                                           endTime: endTime)
        let chunks = try _makeChunks(events: events,
                                     tempos: tempos,
                                     pans: pans,
                                     annotations: annotations,
                                     sortedBoundaries: sortedBoundaries,
                                     divisions: divisions)

        return _groupIntoMeasures(chunks: chunks, measureCount: measureCount, divisions: divisions)
    }

    // A part's own name is its `<part-name>` — `determinePartName(_:)` reads
    // that directly, unlike Guido's single `\instrument`-name identity
    // channel — so the name and the (optional) instrument assignment travel
    // independently and neither has to stand in for the other.
    private static func _makeScorePart(id: String,
                                       part: Part<BeatTime, Pitch>) -> MusicXML.ScorePart {
        var instruments: [MXLScoreInstrument] = []
        var group2: [MusicXML.ScorePart.Group2] = []
        let first = _firstInstrument(part.instrumentMap)

        // Elevation lives on the `PanMap` — it is a flavor of pan, not of
        // instrument — but MusicXML declares it inside `<midi-instrument>`,
        // so a part carrying elevation and no instrument assignment at all
        // still needs a `<score-instrument>`/`<midi-instrument>` pair (named
        // for `.vanilla`, as `MusicXML.Importer._makePanMap` assumes on the
        // way back in) for the elevation to have anywhere to go.
        let elevation = doubleValue(_firstPanExtras(part.panMap), .panVertical)

        if first != nil || elevation != nil {
            let instrument = first?.instrument ?? .vanilla
            let instrumentID = id + "-I1"

            instruments.append(MXLScoreInstrument(id: instrumentID, name: instrument.stringValue))

            let exactProgram = intValue(first?.extras, .midiProgram)
            let derivedProgram = generalMIDIProgramNumber(name: instrument.stringValue).map { $0 + 1 }
            let midiProgram = (exactProgram ?? derivedProgram).flatMap { MXLMidi128(uintValue: UInt($0)) }
            let midiChannel = intValue(first?.extras, .midiChannel).flatMap { MXLMidi16(uintValue: UInt($0)) }
            let midiBank = intValue(first?.extras, .midiBank).flatMap { MXLMidi16384(uintValue: UInt($0)) }
            let exactUnpitched = intValue(first?.extras, .midiUnpitched)
            let derivedUnpitched = generalMIDIPercussionNote(name: instrument.stringValue).map { $0 + 1 }
            let midiUnpitched = (exactUnpitched ?? derivedUnpitched).flatMap { MXLMidi128(uintValue: UInt($0)) }
            let volume = doubleValue(first?.extras, .midiVolume)

            // `<midi-program>` is optional per the MusicXML schema, so a
            // `.vanilla` instrument imported from a channel/bank/volume/
            // unpitched-only `<midi-instrument>` (see
            // `MusicXML.Importer._makeInstrumentMap`) still round-trips
            // its data even though no program can be derived for it —
            // emitting the element on any one field being present, not
            // gating the whole thing on `midiProgram` alone.
            if midiProgram != nil || midiChannel != nil || midiBank != nil ||
               midiUnpitched != nil || volume != nil || elevation != nil {
                group2.append(MusicXML.ScorePart.Group2(midiInstrument: MXLMidiInstrument(id: instrumentID,
                                                                                          midiChannel: midiChannel,
                                                                                          midiBank: midiBank,
                                                                                          midiProgram: midiProgram,
                                                                                          midiUnpitched: midiUnpitched,
                                                                                          volume: volume,
                                                                                          elevation: elevation)))
            }
        }

        return MusicXML.ScorePart(id: id,
                                  name: MXLPartName(value: part.name, text: MXLPartName.Text()),
                                  instrument: instruments,
                                  group2: group2)
    }

    // The note/chord or rest item(s) covering one boundary interval.
    private static func _makeSegmentItems(events: [Event],
                                          start: BeatTime,
                                          end: BeatTime,
                                          divisions: Int) throws(MusicXML.Error) -> [MXLMusicItem] {
        let segmentDuration = BeatDuration(end.numberValue - start.numberValue)
        let mxlDuration = convertToMusicXMLDivisions(segmentDuration, divisions).require()

        guard let event = events.first(where: { $0.attack <= start && $0.end >= end })
        else {
            return [.note(MXLNote(content: .regularNote(fullNote: MXLFullNote(isChord: false, content: .rest(MXLRest())),
                                                        duration: mxlDuration,
                                                        tie: [])))]
        }

        return try _makeNoteItems(pitches: event.pitches,
                                  duration: mxlDuration,
                                  tiedFromPrevious: event.attack != start,
                                  tiedToNext: event.end != end,
                                  extrasList: event.extrasList,
                                  isFirstSegment: event.attack == start,
                                  isLastSegment: event.end == end)
    }

    // A `<direction>` requires at least one `<direction-type>` child even
    // when all it carries is a `<sound>` playback hint — an empty `<words>`
    // is the conventional, invisible placeholder for a direction with
    // nothing of its own to display.
    private static func _makeSoundDirection(_ sound: MXLSound) -> MXLDirection {
        MXLDirection(kind: [MXLDirection.Kind(content: .words(MXLFormattedTextID(value: "")))],
                     sound: sound)
    }

    private static func _makeWedgeDirection(kind: MXLWedge.Kind,
                                            dynamic: Dynamic) -> MXLMusicItem {
        var kinds: [MXLDirection.Kind] = []

        if let item = convertToMusicXMLDynamics(dynamic) {
            kinds.append(MXLDirection.Kind(content: .dynamics([MXLDynamics(items: [item])])))
        }

        kinds.append(MXLDirection.Kind(content: .wedge(MXLWedge(kind: kind))))

        return .direction(MXLDirection(kind: kinds))
    }

    // A work with nothing in it has no `beatTimeRange` to derive a measure
    // count from — treated as one (empty, rest-filled) measure rather than
    // force-unwrapped away.
    private static func _measureCount(work: Work) -> UInt {
        guard let range = work.beatTimeRange
        else { return 1 }

        let measures = (range.upperBound.doubleValue / 4).rounded(.up)

        return max(1, UInt(measures))
    }

    private static func _panDirectives(_ panMap: PanMap<BeatTime>) -> [(BeatTime, Pan, Double?)] {
        var directives: [(BeatTime, Pan, Double?)] = []

        panMap.forEach { _, time, pan, extras in directives.append((time, pan, doubleValue(extras, .panHorizontal))) }

        return directives
    }

    private static func _tempoDirectives(_ tempoMap: TempoMap) -> [(BeatTime, Tempo)] {
        var directives: [(BeatTime, Tempo)] = []

        tempoMap.forEach { _, time, tempo, _ in directives.append((time, tempo)) }

        return directives
    }
}

// MARK: - ExporterProtocol

extension MusicXML.Exporter: ExporterProtocol {

    // MARK: Internal Instance Properties

    internal var writableFileFormats: [FileFormat] {
        [.musicXML,
         .mxl]
    }

    // MARK: Internal Instance Methods

    internal func write(works: [Work],
                        as fileFormat: FileFormat) throws(MusicXML.Error) -> FileWrapper {
        switch fileFormat {
        case .musicXML,
             .mxl:
            guard !works.isEmpty
            else { throw MusicXML.Error.noWorksToExport }

            guard let work = works.first,
                  works.count == 1
            else { throw MusicXML.Error.multipleWorksNotSupported }

            let score = try convert(work)
            let document = MusicXML.Document(content: .scorePartwise(score))
            let data = try MusicXML.Formatter().format(document,
                                                       compressed: fileFormat == .mxl)

            return FileWrapper(regularFileWithContents: data)

        default:
            throw MusicXML.Error.unsupportedFileFormat(fileFormat.displayName)
        }
    }
}

// MARK: - Sendable

extension MusicXML.Exporter: Sendable {
}
