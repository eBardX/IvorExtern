// © 2025–2026 John Gary Pusey (see LICENSE.md)

internal import Foundation
internal import IvorGMN
internal import IvorModel

private import IvorGeneralMIDI
private import IvorMIDI
private import IvorTiming
private import IvorTuning
private import XestiNumbers
private import XestiTools

extension Guido {

    // MARK: Internal Nested Types

    // Not a namespace: `ExporterProtocol`'s instance members live in the
    // following extension, invisible to this check from here.
    // swiftformat:disable:next enumNamespaces
    internal struct Exporter { // swiftlint:disable:this convenience_type

        // MARK: Private Nested Types

        private enum DynamicAnnotation {
            case mark(time: BeatTime, dynamic: Dynamic, mark: String?)
            case ramp(start: BeatTime, startDynamic: Dynamic, end: BeatTime, endDynamic: Dynamic, direction: GMNDynamicRamp.Direction)
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

    internal func convert(_ work: Work,
                          workIndex: Int? = nil,
                          warnings: WarningCollector = WarningCollector()) throws(Guido.Error) -> Guido.Score {
        do {
            return try Self._convert(work: work,
                                     workIndex: workIndex,
                                     warnings: warnings)
        } catch let error as any EnhancedError {
            throw Guido.Error.convertFailure(error)
        } catch {
            throw Guido.Error.convertFailure(nil)
        }
    }

    // MARK: Private Type Methods

    // The sorted union of every time this part's body needs to notice: `.zero`
    // and the work's end, every bar line, every key signature change, every
    // note's attack and end, and every tempo/instrument/pedal/dynamic
    // annotation's own time. Splitting a
    // note at one of these — even one with no note of its own — is what lets a
    // tempo change, instrument change, pedal change, or dynamic mark/ramp boundary land
    // exactly where the model says it should.
    private static func _boundaries(tones: [ExportTone],
                                    directives: [(BeatTime, GMNTag)],
                                    tempos: [(BeatTime, GMNTempo)],
                                    annotations: [DynamicAnnotation],
                                    barTimes: Set<BeatTime>,
                                    keyTimes: [BeatTime],
                                    endTime: BeatTime) -> [BeatTime] {
        var boundaries: Set<BeatTime> = [.zero, endTime]

        for barTime in barTimes {
            boundaries.insert(barTime)
        }

        for keyTime in keyTimes {
            boundaries.insert(keyTime)
        }

        for tone in tones {
            boundaries.insert(tone.attack)
            boundaries.insert(tone.end)
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

    private static func _convert(work: Work,
                                 workIndex: Int?,
                                 warnings: WarningCollector) throws(Guido.Error) -> Guido.Score {
        guard case let .standardBeat(parts, tempoMap, meterTable, keyTable) = work.content
        else {
            guard work.pitchNotation == .standard
            else { throw Guido.Error.unsupportedPitchNotation(work.pitchNotation) }

            throw Guido.Error.unsupportedTimeBasis(work.timeBasis)
        }

        let bars = exportBars(meterTable,
                              through: work.beatTimeRange?.upperBound ?? .zero)
        let voices = try _makeBody(work: work,
                                   parts: parts,
                                   bars: bars,
                                   tempoMap: tempoMap,
                                   keyTable: keyTable,
                                   warnings: warnings,
                                   workIndex: workIndex)

        return Guido.Score(variables: [], voices: voices)
    }

    // A dynamic map's shapes as annotations: a mark as a `\intensity` mark,
    // and a ramp as a dynamic ramp.
    private static func _dynamicAnnotations(_ dynamicMap: DynamicMap<BeatTime>) -> [DynamicAnnotation] {
        DynamicShape.shapes(of: dynamicMap).map {
            switch $0 {
            case let .mark(time, dynamic, mark):
                .mark(time: time, dynamic: dynamic, mark: mark)

            case let .ramp(start, startDynamic, end, endDynamic):
                .ramp(start: start,
                      startDynamic: startDynamic,
                      end: end,
                      endDynamic: endDynamic,
                      direction: endDynamic > startDynamic ? .crescendo : .diminuendo)
            }
        }
    }

    // The tags opening the first voice (see `determineWorkInfo(_:)` for
    // the reverse mapping): `\title` for the title — or the work's name,
    // without one — and again for each subtitle and alternate title, GMN's
    // only kind of secondary title; `\composer` for each credit, with any
    // role other than composer spelled out, since it's GMN's only creator
    // tag; `\footer` for each rights notice and each remark labeled as a
    // footer; and a bodiless `\label` for each remark labeled as a label.
    // GMN has nothing to hold a parent work's title, a dedication, or any
    // other remark.
    // These tags hold a single line, so line breaks become spaces.
    private static func _infoTags(_ info: Work.Info,
                                  name: String) -> [GMNSymbol] {
        var tags: [GMNTag] = []

        for title in [info.title ?? name.nilIfEmpty].compactMap(\.self) + info.subtitles + info.alternateTitles {
            tags.append(.titleBlock(GMNTitleBlock(kind: .title, text: title)))
        }

        for credit in info.credits {
            let text = credit.role == .composer ? credit.name : describeCredit(credit)

            tags.append(.titleBlock(GMNTitleBlock(kind: .composer, text: text)))
        }

        for notice in info.rights {
            tags.append(.titleBlock(GMNTitleBlock(kind: .footer, text: singleLine(notice.text))))
        }

        for remark in info.remarks {
            switch remark.label {
            case RemarkLabel.footer:
                tags.append(.titleBlock(GMNTitleBlock(kind: .footer, text: singleLine(remark.text))))

            case RemarkLabel.label:
                tags.append(.text(GMNText(kind: .label, text: singleLine(remark.text))))

            default:
                break
            }
        }

        return tags.map { .tag($0) }
    }

    private static func _instrumentDirectives(_ instrumentTable: InstrumentTable<BeatTime>) -> [(BeatTime, GMNTag)] {
        var directives: [(BeatTime, GMNTag)] = []

        for entry in instrumentTable {
            let exactProgram = intValue(entry.extras, .midiProgram)
            let derivedProgram = GM1Instrument(name: entry.instrument.stringValue).map { Int($0.program.uintValue) }
            let midi = (exactProgram ?? derivedProgram).map { $0 - 1 }

            let name = stringValue(entry.extras, .instrumentName) ?? entry.instrument.stringValue

            directives.append((entry.time, .instrument(GMNInstrument(name: name, midi: midi))))
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
    // own symbol(s) (and any articulation wrapping above), from the tones
    // attacked there. A `slurStart` extra with no
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

    // Every voice opens with the first bar's meter (see
    // `exportBars(_:through:)`), and writes every key, though the
    // importer reads only the first voice's.
    private static func _makeBody(work: Work,
                                  parts: [Part<BeatTime, Pitch>],
                                  bars: [ExportBar],
                                  tempoMap: TempoMap,
                                  keyTable: KeyTable,
                                  warnings: WarningCollector,
                                  workIndex: Int?) throws(Guido.Error) -> [Guido.Voice] {
        let firstMeter = bars.first.map { convertToGuidoMeter($0.meter, $0.extras) } ?? GMNMeter(type: "4/4")
        let sharedRolls = RollKey.sharedRolls(parts)
        var voices: [Guido.Voice] = []

        for index in parts.indices {
            var symbols: [GMNSymbol] = [.tag(.meter(firstMeter))]

            if index == 0 {
                symbols += _infoTags(work.info, name: work.name)
            }

            // `\instrument`'s `name` is Guido's only per-voice identity
            // carrier — `determinePartName(_:)` reads the *first* one found
            // in the voice — so a non-empty part name always gets one, ahead
            // of any real instrument-table-driven tag below. When both land at
            // the same time the real tag's later `insert` simply overwrites
            // this one's entry in the recovered `InstrumentTable`, so neither
            // clobbers the other on round trip. A part with no name and no
            // instrument table entries emits nothing here, so it costs nothing
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
                                         partIndex: index,
                                         bars: bars,
                                         tempoMap: index == 0 ? tempoMap : TempoMap(),
                                         keyTable: keyTable,
                                         sharedRolls: sharedRolls,
                                         warnings: warnings,
                                         workIndex: workIndex)

            voices.append(GMNVoice(symbols: symbols))
        }

        return voices
    }

    // Lays one part's notes onto the work's bars (see
    // `exportBars(_:through:)`): each piece between boundaries (see
    // `ExportSlice`) is one note, chord or rest, and every bar sums to its
    // actual length, so a pickup or a short bar is written short. A note or
    // chord whose every tone continues into the next piece (across a
    // barline, say) is tied by a bare `\tieEnd` marker after it. When only
    // some tones continue, each is tied on its own, guidolib's way:
    // `{ \tieBegin:1 c, e } { c \tieEnd:1, g }`, an ident per open tie. A bar whose meter is written (other than the first,
    // whose `\meter` opens the voice) starts with a `\meter` tag, and a key
    // signature is a `\key` tag at its own time.
    //
    // `Guido.Importer.Walker._handleTag` flushes the pending note and clears
    // the tie-armed flag on every tag other than `\tieEnd`, `\bar`, `\meter`
    // and `\key`, so a directive or mark can never appear between two segments
    // of the same tied note without breaking the tie. A segment boundary
    // with nothing but a barline (and perhaps a meter) is where a tie
    // continues; any other boundary has no tied note across it.
    private static func _makeChunks(slices: [ExportSlice],
                                    directives: [(BeatTime, GMNTag)],
                                    tempos: [(BeatTime, GMNTempo)],
                                    annotations: [DynamicAnnotation],
                                    barTimes: Set<BeatTime>,
                                    meterTags: [BeatTime: GMNMeter],
                                    keyTags: [BeatTime: GMNKey],
                                    writer: inout OrnamentWriter) throws(Guido.Error) -> [(start: BeatTime, symbols: [GMNSymbol])] {
        var chunks: [(start: BeatTime, symbols: [GMNSymbol])] = []
        var directiveIndex = 0
        var tempoIndex = 0
        var tieIdents: [Int: GMNTag.Ident] = [:]

        for slice in slices {
            let start = slice.start
            let end = slice.end
            var symbols: [GMNSymbol] = meterTags[start].map { [.tag(.meter($0))] } ?? []

            symbols += keyTags[start].map { [.tag(.key($0))] } ?? []

            while tempoIndex < tempos.count, tempos[tempoIndex].0 <= start {
                symbols.append(.tag(.tempo(tempos[tempoIndex].1)))
                tempoIndex += 1
            }

            while directiveIndex < directives.count, directives[directiveIndex].0 <= start {
                symbols.append(.tag(directives[directiveIndex].1))
                directiveIndex += 1
            }

            for annotation in annotations {
                if let intensity = _intensity(for: annotation, at: start) {
                    symbols.append(.tag(.intensity(intensity)))
                }
            }

            let segmentDuration = BeatDuration(end.numberValue - start.numberValue)

            if slice.tones.isEmpty {
                symbols += try writer.wrapRest(_makeRestSymbols(duration: segmentDuration), at: start)
            } else {
                symbols += try _segmentSymbols(slice: slice,
                                               duration: segmentDuration,
                                               tieIdents: &tieIdents,
                                               writer: &writer)
            }

            if slice.isWhollyTied {
                symbols.append(.tag(.tie(GMNTie(span: .end).require())))
            }

            if barTimes.contains(end) {
                symbols.append(writer.barLineSymbol(GMNBarLine(kind: .single), at: end))
            }

            chunks.append((start, symbols))
        }

        return chunks
    }

    private static func _makePartBody(part: Part<BeatTime, Pitch>,
                                      partIndex: Int,
                                      bars: [ExportBar],
                                      tempoMap: TempoMap,
                                      keyTable: KeyTable,
                                      sharedRolls: [RollKey: Int],
                                      warnings: WarningCollector,
                                      workIndex: Int?) throws(Guido.Error) -> [GMNSymbol] {
        let tones = ExportTone.tones(of: part.noteTable)
        let directives = (_instrumentDirectives(part.instrumentTable) + _pedalDirectives(part.pedals[.sustain]))
            .enumerated()
            .sorted { ($0.element.0, $0.offset) < ($1.element.0, $1.offset) }
            .map(\.element)
        let tempos = _tempoDirectives(tempoMap)
        let annotations = _dynamicAnnotations(part.dynamicMap)
        let barTimes = Set(bars.dropFirst().map(\.start))
        let endTime = bars.last?.end ?? .zero
        var meterTags: [BeatTime: GMNMeter] = [:]

        for bar in bars.dropFirst() where bar.isMeterWritten {
            meterTags[bar.start] = convertToGuidoMeter(bar.meter, bar.extras)
        }

        var keyTags: [BeatTime: GMNKey] = [:]

        for entry in keyTable where entry.beatTime < endTime || entry.beatTime == .zero {
            keyTags[entry.beatTime] = convertToGMNKey(entry.key)
        }

        let sortedBoundaries = _boundaries(tones: tones,
                                           directives: directives,
                                           tempos: tempos,
                                           annotations: annotations,
                                           barTimes: barTimes,
                                           keyTimes: Array(keyTags.keys),
                                           endTime: endTime)
        let slices = ExportSlice.slices(of: tones,
                                        at: sortedBoundaries)
        var writer = OrnamentWriter(markTable: part.markTable,
                                    partIndex: partIndex,
                                    sharedRolls: sharedRolls,
                                    sliceStarts: Set(slices.map(\.start)),
                                    barTimes: barTimes.union([endTime]),
                                    warnings: warnings,
                                    workIndex: workIndex)
        let chunks = try _makeChunks(slices: slices,
                                     directives: directives,
                                     tempos: tempos,
                                     annotations: annotations,
                                     barTimes: barTimes,
                                     meterTags: meterTags,
                                     keyTags: keyTags,
                                     writer: &writer)

        var body = _wrapDynamicRamps(chunks: chunks, annotations: annotations)

        body.append(writer.barLineSymbol(GMNBarLine(kind: .final), at: endTime))

        return body
    }

    private static func _makeRestSymbols(duration: BeatDuration) throws(Guido.Error) -> [GMNSymbol] {
        guard let length = convertToGuidoDuration(duration)
        else { throw Guido.Error.unrepresentableDuration("\(duration)") }

        return [.rest(GMNRest(duration: length))]
    }

    // A tone in `beginIdents` gets a `\tieBegin` before it, and one in
    // `endIdents` a `\tieEnd` after it, both keyed by the tone's index; only
    // a chord segment can hold them, so a lone tone with either is written
    // as a one-tone chord.
    private static func _makeSymbols(tones: [ExportTone],
                                     duration: BeatDuration,
                                     beginIdents: [Int: GMNTag.Ident],
                                     endIdents: [Int: GMNTag.Ident]) throws(Guido.Error) -> [GMNSymbol] {
        guard let length = convertToGuidoDuration(duration)
        else { throw Guido.Error.unrepresentableDuration("\(duration)") }

        if tones.count == 1, beginIdents.isEmpty, endIdents.isEmpty {
            let pitch = try convertToGuidoPitch(tones[0].pitch)

            return [.note(GMNNote(pitch: pitch, duration: length))]
        }

        var segments: [GMNChord.Segment] = []

        for tone in tones {
            let gPitch = try convertToGuidoPitch(tone.pitch)
            var symbols: [GMNSymbol] = []

            if let ident = beginIdents[tone.index] {
                symbols.append(.tag(.tie(GMNTie(ident: ident, span: .begin).require())))
            }

            symbols.append(.note(GMNNote(pitch: gPitch, duration: length)))

            if let ident = endIdents[tone.index] {
                symbols.append(.tag(.tie(GMNTie(ident: ident, span: .end).require())))
            }

            guard let segment = GMNChord.Segment(symbols: symbols)
            else { throw Guido.Error.unrepresentableDuration("\(duration)") }

            segments.append(segment)
        }

        guard let chord = GMNChord(segments: segments)
        else { throw Guido.Error.unrepresentableDuration("\(duration)") }

        return [.chord(chord)]
    }

    // Guido has only the damper pedal, so only the sustain table is written,
    // thresholded at `Pedal.Level.isDown`: `\pedalOn` where it goes down,
    // `\pedalOff` where it comes up, and `\pedalOff \pedalOn` for a re-pedal.
    // The other pedals are dropped. Each tag lands ahead of the note at its
    // time, after any instrument change there.
    private static func _pedalDirectives(_ table: PedalTable<BeatTime>?) -> [(BeatTime, GMNTag)] {
        var directives: [(BeatTime, GMNTag)] = []
        var previous: Pedal.Level = .up

        for (time, levels) in groupedByTime(table ?? PedalTable()) {
            for isDown in pedalSwitches(after: previous, levels) {
                directives.append((time, .pedal(GMNPedal(kind: isDown ? .on : .off))))
            }

            previous = levels.last ?? previous
        }

        return directives
    }

    // One slice's own symbols: articulation-wrapped note/chord symbols,
    // with a leading `\slurBegin:n` from the tones attacked there and a
    // trailing `\slurEnd:n` from the tones released there. `tieIdents`
    // holds the ident of each tone tied on its own (see
    // `_makePartBody(part:bars:tempoMap:keyTable:)`), by the tone's index:
    // this closes the ones tied into `slice`, and opens one for each tone
    // that continues past it, unless every tone does.
    private static func _segmentSymbols(slice: ExportSlice,
                                        duration: BeatDuration,
                                        tieIdents: inout [Int: GMNTag.Ident],
                                        writer: inout OrnamentWriter) throws(Guido.Error) -> [GMNSymbol] {
        var endIdents: [Int: GMNTag.Ident] = [:]
        var beginIdents: [Int: GMNTag.Ident] = [:]

        for tone in slice.tones {
            if let ident = tieIdents.removeValue(forKey: tone.index) {
                endIdents[tone.index] = ident
            }
        }

        if !slice.isWhollyTied {
            var usedIdents = Set(tieIdents.values.map(\.uintValue)).union(endIdents.values.map(\.uintValue))

            for tone in slice.tones where slice.continues(tone) {
                let uintValue = (1...).first { !usedIdents.contains($0) } ?? 1
                let ident = GMNTag.Ident(uintValue: uintValue).require()

                usedIdents.insert(uintValue)
                beginIdents[tone.index] = ident
                tieIdents[tone.index] = ident
            }
        }

        var symbols: [GMNSymbol] = []
        let twoNoteTremolo = try writer.twoNoteTremoloSymbols(slice, duration: duration)
        var noteSymbols: [GMNSymbol] = if let twoNoteTremolo {
            twoNoteTremolo
        } else {
            try _makeSymbols(tones: slice.tones,
                             duration: duration,
                             beginIdents: beginIdents,
                             endIdents: endIdents)
        }
        let attackedTones = slice.attackedTones
        let releasedTones = slice.releasedTones

        if !attackedTones.isEmpty {
            noteSymbols = _wrapArticulations(noteSymbols, attackedTones.map(\.extras))
            noteSymbols = writer.wrapOrnaments(noteSymbols,
                                               attackedTones: attackedTones,
                                               start: slice.start,
                                               duration: duration,
                                               includesOrnament: twoNoteTremolo == nil)
            symbols += _leadingSlurStartSymbols(attackedTones.map(\.extras))
            symbols += try writer.graceSymbols(attackedTones)
        }

        symbols += noteSymbols

        if !releasedTones.isEmpty {
            symbols += _trailingSlurEndSymbols(releasedTones.map(\.extras))
            writer.carryFigureAfter(releasedTones)
        }

        return symbols
    }

    private static func _tempoDirectives(_ tempoMap: TempoMap) -> [(BeatTime, GMNTempo)] {
        var directives: [(BeatTime, GMNTempo)] = []

        for entry in tempoMap {
            if let gTempo = convertToGuidoTempo(entry.tempo, text: stringValue(entry.extras, .tempoText)) {
                directives.append((entry.beatTime, gTempo))
            }
        }

        return directives
    }

    // A `\slurEnd:n` marker, written immediately after a note/chord's own
    // symbol(s), from the tones released there. Same id-only
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

    // Wraps `symbols` (a slice's own note/chord symbol(s)) one layer per
    // Tier 1/fingering/breathMark extra present, innermost-first, from the
    // tones attacked there (a tie-continuation carries no repeated
    // wrapping). `body:`-form tags are the only
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

    internal var supportedOptions: Set<ExportOptions.Key> {
        []
    }

    internal var writableFileFormats: [FileFormat] {
        [.gmn]
    }

    // MARK: Internal Instance Methods

    internal func write(works: [Work],
                        as fileFormat: FileFormat,
                        options: ExportOptions = .default,
                        warnings: WarningCollector = WarningCollector()) throws(Guido.Error) -> FileWrapper {
        switch fileFormat {
        case .gmn:
            guard !works.isEmpty
            else { throw Guido.Error.noWorksToExport }

            guard let work = works.first,
                  works.count == 1
            else { throw Guido.Error.multipleWorksNotSupported }

            let score = try convert(work, workIndex: 0, warnings: warnings)
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
