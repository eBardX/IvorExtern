// © 2025–2026 John Gary Pusey (see LICENSE.md)

internal import Foundation
internal import IvorModel

private import IvorMusicXML
private import IvorTiming
private import IvorTuning
private import XestiTools

extension MusicXML {
    internal struct Importer {
    }
}

// MARK: -

extension MusicXML.Importer {

    // MARK: Internal Instance Methods

    internal func convert(_ document: MusicXML.Document) throws(MusicXML.Error) -> Work {
        do {
            return try Self._convert(document)
        } catch let error as any EnhancedError {
            throw MusicXML.Error.convertFailure(error)
        } catch {
            throw MusicXML.Error.convertFailure(nil)
        }
    }

    // MARK: Private Type Methods

    private static func _convert(_ document: MusicXML.Document) throws -> Work {
        let (normalized, _) = MusicXML.Normalizer().normalize(document)
        let (validated, issues) = try MusicXML.Validator().validate(normalized)

        guard issues.isEmpty
        else { throw MusicXML.Error.validationFailure(issues) }

        guard case let .scorePartwise(score) = validated.content
        else { throw MusicXML.Error.unsupportedScoreFormat("opus") }

        let plan = try Plan(score)
        let results = try Walker().walk(score, order: plan.order)
        let groupNames = _groupNames(score)

        return try Work(name: determineWorkName(score),
                        content: .standardBeat(_convert(results, groupNames),
                                               _makeTempoMap(results.flatMap(\.tempoEvents))))
    }

    // Each Ivor `Part` carries a single note table, so a MusicXML part with
    // several simultaneous voices becomes several Ivor `Part`s — one per
    // voice — rather than collapsing them together. A part with no voices
    // still yields one empty `Part`, named by `determinePartName`. Pan, like
    // an instrument assignment, applies to the whole MusicXML part rather
    // than any one voice, so every voice split from the same part shares the
    // one pan map built from that part's own `<sound>` events. Dynamics
    // split the opposite way: a voice with any note carrying its own
    // `dynamics` (velocity) attribute uses a map built purely from those —
    // the more precise, MIDI-style source — falling back to the part's
    // shared, notated `<direction>` dynamics marks only when the voice has
    // no velocity data of its own.
    private static func _convert(_ part: MusicXML.Part,
                                 groupName: String?,
                                 panMap: PanMap<BeatTime>,
                                 directionDynamicMap: DynamicMap<BeatTime>) -> [Part<BeatTime, Pitch>] {
        let instrumentMap = _makeInstrumentMap(part.part)

        guard !part.voices.isEmpty
        else { return [Part(name: determinePartName(part.part, groupName: groupName),
                            noteTable: NoteTable(),
                            dynamicMap: directionDynamicMap,
                            instrumentMap: instrumentMap,
                            panMap: panMap)] }

        return part.voices.enumerated().map { index, voice in
            let dynamicMap = voice.noteDynamicEvents.isEmpty ? directionDynamicMap : _makeDynamicMap(voice.noteDynamicEvents)

            return Part(name: _makePartName(part.part,
                                            groupName,
                                            voice,
                                            index,
                                            part.voices.count),
                        noteTable: voice.noteTable,
                        dynamicMap: dynamicMap,
                        instrumentMap: instrumentMap,
                        panMap: panMap)
        }
    }

    private static func _convert(_ results: [Walker.WalkResult],
                                 _ groupNames: [String: String]) -> [Part<BeatTime, Pitch>] {
        results.flatMap {
            _convert($0.part,
                     groupName: groupNames[$0.part.part.id],
                     panMap: _makePanMap($0.panEvents),
                     directionDynamicMap: _makeDirectionDynamicMap($0.directionDynamicEvents))
        }
    }

    // Maps each score-part id to the name of its nearest enclosing *named*
    // `<part-group>` — skipping outward past an unnamed brace/bracket
    // nested directly around it, such as the plain bracket MuseScore (and
    // others) write around a "1 2"/"3 4" divisi pair in addition to the
    // named brace around the whole instrument family — or `nil` if it has
    // none. A `<part-group>`'s `number` disambiguates overlapping/nested
    // groups, not sequence, and the same number is reused across separate,
    // non-overlapping sibling groups later in the list (see
    // `ActorPreludeSample.mxl`'s flutes/oboes pairs, each their own
    // `number="2"`), so this is a proper open/close stack keyed by number,
    // not a running "current name per number" table.
    private static func _groupNames(_ score: MusicXML.Score) -> [String: String] {
        var openGroups: [(number: String, name: String?)] = []
        var groupNames: [String: String] = [:]

        for item in score.partList.items {
            switch item {
            case let .partGroup(group) where group.kind == .start:
                openGroups.append((group.number, group.name?.value.nilIfEmpty))

            case let .partGroup(group) where group.kind == .stop:
                if let index = openGroups.lastIndex(where: { $0.number == group.number }) {
                    openGroups.remove(at: index)
                }

            case let .scorePart(scorePart):
                if let name = openGroups.last(where: { $0.name != nil })?.name {
                    groupNames[scorePart.id] = name
                }

            default:
                break
            }
        }

        return groupNames
    }

    // Unlike `_makeDynamicMap` below, this isn't a uniform reassert-then-
    // insert step builder: a `.step` event (a `<sound>`'s `dynamics` or a
    // notated `<dynamics>` mark) still gets that treatment, since it is an
    // instant change, but a `.rampBoundary` event (one endpoint of a
    // `<wedge>`) is inserted plainly and left for `DynamicMap`'s own linear
    // interpolation to glide across — reasserting it first would turn the
    // glide back into a step. Mirrors Guido's and ABC's own dynamics-map
    // builders.
    private static func _makeDirectionDynamicMap(_ events: [MusicXML.Importer.Context.DynamicEvent]) -> DynamicMap<BeatTime> {
        var dynamicMap = DynamicMap<BeatTime>()
        var previousDynamic: Dynamic = .mp

        for event in events.sorted(by: { $0.beatTime < $1.beatTime }) {
            switch event.kind {
            case .rampBoundary:
                dynamicMap.insert(time: event.beatTime, dynamic: event.dynamic)

            case .step:
                if event.beatTime != .zero {
                    dynamicMap.insert(time: event.beatTime, dynamic: previousDynamic)
                }

                dynamicMap.insert(time: event.beatTime, dynamic: event.dynamic)
            }

            previousDynamic = event.dynamic
        }

        return dynamicMap
    }

    // The same prev/curr double-insert step `_makeTempoMap` uses below, for
    // the same reason: a `DynamicMap` lookup finds the dynamic active *at or
    // before* a time, so the dynamic in effect immediately before a change
    // has to be reasserted at the change's own beat position before the new
    // dynamic is inserted there too. Every event this builds from — a
    // note's own velocity — is a discrete point, not a ramp, so unlike
    // `_makeDirectionDynamicMap` above this one never needs a second,
    // plain-insert code path.
    private static func _makeDynamicMap(_ events: [(beatTime: BeatTime, dynamic: Dynamic)]) -> DynamicMap<BeatTime> {
        var dynamicMap = DynamicMap<BeatTime>()
        var previousDynamic: Dynamic = .mp

        for event in events.sorted(by: { $0.beatTime < $1.beatTime }) {
            if event.beatTime != .zero {
                dynamicMap.insert(time: event.beatTime, dynamic: previousDynamic)
            }

            dynamicMap.insert(time: event.beatTime, dynamic: event.dynamic)
            previousDynamic = event.dynamic
        }

        return dynamicMap
    }

    // An instrument assignment, like pan, applies to the whole MusicXML part
    // rather than any one voice — see the type-level comment above — so
    // every voice split from the same part shares this one map. A part with
    // no usable instrument data (see `convertToInstrument(_:)`) gets an
    // empty map, which reads as `Instrument.vanilla` via `InstrumentMap`'s
    // own default.
    private static func _makeInstrumentMap(_ scorePart: MusicXML.ScorePart) -> InstrumentMap<BeatTime> {
        var instrumentMap = InstrumentMap<BeatTime>()

        if let instrument = convertToInstrument(scorePart) {
            instrumentMap.insert(time: .zero, instrument: instrument)
        }

        return instrumentMap
    }

    // The same prev/curr double-insert step `_makeTempoMap` uses below, for
    // the same reason: a `PanMap` lookup finds the pan active *at or before*
    // a time, so the pan in effect immediately before a change has to be
    // reasserted at the change's own beat position before the new pan is
    // inserted there too.
    private static func _makePanMap(_ events: [(beatTime: BeatTime, pan: Pan)]) -> PanMap<BeatTime> {
        var panMap = PanMap<BeatTime>()
        var previousPan: Pan = .center

        for event in events.sorted(by: { $0.beatTime < $1.beatTime }) {
            if event.beatTime != .zero {
                panMap.insert(time: event.beatTime, pan: previousPan)
            }

            panMap.insert(time: event.beatTime, pan: event.pan)
            previousPan = event.pan
        }

        return panMap
    }

    // A part's own name is used as-is when it has a single voice — the
    // common case, and the name a listener actually recognizes — and
    // disambiguated with the `<voice>` element's identifier only when there
    // is more than one, falling back to a 1-based position for the implicit
    // voice a part never declares one for.
    private static func _makePartName(_ scorePart: MusicXML.ScorePart,
                                      _ groupName: String?,
                                      _ voice: MusicXML.Voice,
                                      _ index: Int,
                                      _ voiceCount: Int) -> String {
        let partName = determinePartName(scorePart, groupName: groupName)

        guard voiceCount > 1
        else { return partName }

        let voiceLabel = voice.id ?? String(index + 1)

        return partName.isEmpty ? "Voice \(voiceLabel)" : "\(partName), Voice \(voiceLabel)"
    }

    // The same prev/curr double-insert step MIDI's, Guido's, and ABC's
    // `TempoMap` builders use: a `TempoMap` lookup finds the tempo active *at
    // or before* a beat, so the tempo that was in effect immediately before a
    // change has to be reasserted at the change's own beat position before
    // the new tempo is inserted there too — otherwise the lookup would report
    // the new tempo one instant too early.
    private static func _makeTempoMap(_ events: [(beatTime: BeatTime, tempo: Tempo)]) -> TempoMap {
        var tempoMap = TempoMap()
        var previousTempo: Tempo = .default

        for event in events.sorted(by: { $0.beatTime < $1.beatTime }) {
            if event.beatTime != .zero {
                tempoMap.insert(beatTime: event.beatTime, tempo: previousTempo)
            }

            tempoMap.insert(beatTime: event.beatTime, tempo: event.tempo)
            previousTempo = event.tempo
        }

        return tempoMap
    }

    // MARK: Private Instance Methods

    private func _parse(_ file: FileWrapper,
                        _ compressed: Bool) throws -> MusicXML.Document {
        let data = try file.contentsOfRegularFile()

        return try MusicXML.Parser().parse(data,
                                           compressed: compressed)
    }

    private func _read(_ file: FileWrapper,
                       _ compressed: Bool) throws -> [Work] {
        let document = try _parse(file, compressed)

        return try [convert(document)]
    }
}

// MARK: - ImporterProtocol

extension MusicXML.Importer: ImporterProtocol {

    // MARK: Internal Instance Properties

    internal var readableFileFormats: [FileFormat] {
        [.musicXML,
         .mxl]
    }

    // MARK: Internal Instance Methods

    internal func read(from file: FileWrapper,
                       as fileFormat: FileFormat) throws -> [Work] {
        switch fileFormat {
        case .musicXML:
            return try _read(file, false)

        case .mxl:
            return try _read(file, true)

        default:
            throw MusicXML.Error.unsupportedFileFormat(fileFormat.displayName)
        }
    }
}

// MARK: - Sendable

extension MusicXML.Importer: Sendable {
}
