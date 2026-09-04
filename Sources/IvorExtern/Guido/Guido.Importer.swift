// © 2025–2026 John Gary Pusey (see LICENSE.md)

internal import Foundation
internal import IvorModel

private import IvorGuido
private import IvorTiming
private import IvorTuning
private import XestiTools

extension Guido {
    internal struct Importer {
    }
}

// MARK: -

extension Guido.Importer {

    // MARK: Internal Instance Methods

    internal func convert(_ score: Guido.Score) throws(Guido.Error) -> Work {
        do {
            return try Self._convert(score)
        } catch let error as any EnhancedError {
            throw Guido.Error.convertFailure(error)
        } catch {
            throw Guido.Error.convertFailure(nil)
        }
    }

    // MARK: Private Type Methods

    private static func _convert(_ score: Guido.Score) throws -> Work {
        let (normalized, _) = Guido.Normalizer().normalize(score)
        let (validated, issues) = try Guido.Validator().validate(normalized)

        guard issues.isEmpty
        else { throw Guido.Error.validationFailure(issues) }

        let variables = Dictionary(validated.variables.map { ($0.name, $0) }) { _, latest in latest }
        let walker = Walker(variables: variables)
        let contexts = try validated.voices.map { try walker.walk($0) }
        let parts = zip(validated.voices, contexts).map { voice, context in
            Part(name: determinePartName(voice),
                 noteTable: context.noteTable,
                 dynamicMap: _makeDynamicMap(context.dynamicEvents),
                 instrumentMap: _makeInstrumentMap(context.instrumentEvents))
        }

        return Work(name: determineWorkName(validated),
                    content: .standardBeat(parts,
                                           _makeTempoMap(contexts.flatMap(\.tempoEvents))))
    }

    // Unlike `_makeTempoMap`, this isn't a uniform reassert-then-insert step
    // builder: a `.step` event (an `\intensity` mark) still gets that
    // treatment, since it is an instant change, but a `.rampBoundary` event
    // (one endpoint of a `\crescendo`/`\diminuendo`) is inserted plainly and
    // left for `DynamicMap`'s own linear interpolation to glide across —
    // reasserting it first would turn the glide back into a step. Dynamics
    // are per-voice, unlike tempo, so this runs once per voice rather than
    // once for the whole score.
    private static func _makeDynamicMap(_ events: [Guido.Importer.Context.DynamicEvent]) -> DynamicMap<BeatTime> {
        var dynamicMap = DynamicMap<BeatTime>()
        var prevDynamic: Dynamic = .mp

        for event in events.sorted(by: { $0.beatTime < $1.beatTime }) {
            switch event.kind {
            case .rampBoundary:
                dynamicMap.insert(time: event.beatTime,
                                  dynamic: event.dynamic)

            case .step:
                if event.beatTime != .zero {
                    dynamicMap.insert(time: event.beatTime,
                                      dynamic: prevDynamic)
                }

                dynamicMap.insert(time: event.beatTime,
                                  dynamic: event.dynamic)
            }

            prevDynamic = event.dynamic
        }

        return dynamicMap
    }

    // Unlike `_makeDynamicMap`/`_makeTempoMap`, no reassert-then-insert step
    // is needed: `InstrumentMap`'s own subscript already reads as a step
    // function — the entry in effect at or before a queried time, with no
    // interpolation — so one plain insert per `\instrument` tag is enough.
    private static func _makeInstrumentMap(_ events: [(beatTime: BeatTime, instrument: Instrument)]) -> InstrumentMap<BeatTime> {
        var instrumentMap = InstrumentMap<BeatTime>()

        for event in events.sorted(by: { $0.beatTime < $1.beatTime }) {
            instrumentMap.insert(time: event.beatTime, instrument: event.instrument)
        }

        return instrumentMap
    }

    // Mirrors `MIDI.Importer`'s own `TempoMap` builder: inserting both the
    // previous tempo and the new one at the same beat time turns what would
    // otherwise interpolate into a step, since a `\tempo` tag is an instant
    // change, not a curve.
    private static func _makeTempoMap(_ events: [(beatTime: BeatTime, tempo: Tempo)]) -> TempoMap {
        var tempoMap = TempoMap()
        var prevTempo: Tempo = .default

        for event in events.sorted(by: { $0.beatTime < $1.beatTime }) {
            if event.beatTime != .zero {
                tempoMap.insert(beatTime: event.beatTime,
                                tempo: prevTempo)
            }

            tempoMap.insert(beatTime: event.beatTime,
                            tempo: event.tempo)

            prevTempo = event.tempo
        }

        return tempoMap
    }
}

// MARK: - ImporterProtocol

extension Guido.Importer: ImporterProtocol {

    // MARK: Internal Instance Properties

    internal var readableFileFormats: [FileFormat] {
        [.gmn]
    }

    // MARK: Internal Instance Methods

    internal func read(from file: FileWrapper,
                       as fileFormat: FileFormat) throws(Guido.Error) -> [Work] {
        switch fileFormat {
        case .gmn:
            guard let data = file.regularFileContents
            else { throw Guido.Error.parseFailure(nil) }

            let score = try Guido.Parser().parse(data)
            let work = try convert(score)

            return [work]

        default:
            throw Guido.Error.unsupportedFileFormat(fileFormat.displayName)
        }
    }
}

// MARK: - Sendable

extension Guido.Importer: Sendable {
}
