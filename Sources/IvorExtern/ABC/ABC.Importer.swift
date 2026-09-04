// © 2025–2026 John Gary Pusey (see LICENSE.md)

internal import Foundation
internal import IvorModel

private import IvorABC
private import IvorTiming
private import IvorTuning
private import XestiTools

extension ABC {
    internal struct Importer {
    }
}

// MARK: -

extension ABC.Importer {

    // MARK: Internal Instance Methods

    internal func convert(_ tunebook: ABC.Tunebook) throws(ABC.Error) -> [Work] {
        do {
            return try Self._convert(tunebook)
        } catch let error as any EnhancedError {
            throw ABC.Error.convertFailure(error)
        } catch {
            throw ABC.Error.convertFailure(nil)
        }
    }

    // MARK: Private Type Methods

    private static func _convert(_ tune: ABCTune,
                                 fileHeader: [ABCHeaderEntry]) throws(ABC.Error) -> Work {
        let results = try Walker().walk(tune, fileHeader: fileHeader)
        let instrumentMap = _makeInstrumentMap(_findMIDIProgramDirective(tune, fileHeader: fileHeader))
        let parts = results.compactMap { result -> Part<BeatTime, Pitch>? in
            guard result.identity != nil || !_isEmptyImplicitVoice(result.context)
            else { return nil }

            return Part(name: determinePartName(result.identity),
                        noteTable: result.context.noteTable,
                        dynamicMap: _makeDynamicMap(result.context.dynamicEvents),
                        instrumentMap: instrumentMap)
        }
        let tempoEvents = results.flatMap(\.context.tempoEvents)

        return try Work(name: determineWorkName(tune),
                        content: .standardBeat(parts, _makeTempoMap(tempoEvents)))
    }

    private static func _convert(_ tunebook: ABC.Tunebook) throws -> [Work] {
        let (normalized, _) = ABC.Normalizer().normalize(tunebook)
        let (validated, issues) = try ABC.Validator().validate(normalized)

        guard issues.isEmpty
        else { throw ABC.Error.validationFailure(issues) }

        var works: [Work] = []

        for tune in validated.tunes {
            try works.append(_convert(tune, fileHeader: validated.fileHeader))
        }

        return works
    }

    // ABC's `%%MIDI program` directive assigns one instrument for the whole
    // tune — abc2midi gives it no scoping to a particular voice or bar
    // position — so the first occurrence found, searched in the same
    // file-header/tune-header/tune-body precedence order every other header
    // field resolves in, becomes every voice's single `InstrumentMap` entry.
    private static func _findMIDIProgramDirective(_ tune: ABCTune,
                                                  fileHeader: [ABCHeaderEntry]) -> ABCDirective? {
        for entry in fileHeader + tune.header {
            if case let .directive(directive) = entry,
               convertToInstrument(directive) != nil {
                return directive
            }
        }

        for entry in tune.body {
            if case let .directive(directive) = entry,
               convertToInstrument(directive) != nil {
                return directive
            }
        }

        return nil
    }

    // `ABC.Importer.Walker._routed` always seeds an accumulator for the
    // implicit voice (no `V:` field has matched it yet) so that a plain,
    // voiceless tune still has somewhere to land — see that type's own
    // comment. When the tune *does* use `V:` fields, that seed is never
    // written to and would otherwise surface as a spurious, unnamed leading
    // `Part`; this is the check that lets `_convert` drop it instead. A
    // voiceless tune's sole accumulator is also nameless but never empty,
    // so it's unaffected by this check (the caller only consults it when
    // `identity == nil`).
    private static func _isEmptyImplicitVoice(_ context: ABC.Importer.Context) -> Bool {
        context.noteTable.timeRange == nil && context.dynamicEvents.isEmpty
    }

    // Unlike `_makeTempoMap`, this isn't a uniform reassert-then-insert step
    // builder: a `.step` event (a dynamics decoration) still gets that
    // treatment, since it is an instant change, but a `.rampBoundary` event
    // (one endpoint of a crescendo/diminuendo hairpin) is inserted plainly
    // and left for `DynamicMap`'s own linear interpolation to glide across —
    // reasserting it first would turn the glide back into a step. Dynamics
    // are per-voice, unlike tempo, so this runs once per voice rather than
    // once for the whole tune.
    private static func _makeDynamicMap(_ events: [ABC.Importer.Context.DynamicEvent]) -> DynamicMap<BeatTime> {
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

    private static func _makeInstrumentMap(_ directive: ABCDirective?) -> InstrumentMap<BeatTime> {
        var instrumentMap = InstrumentMap<BeatTime>()

        if let directive, let instrument = convertToInstrument(directive) {
            instrumentMap.insert(time: .zero, instrument: instrument)
        }

        return instrumentMap
    }

    // The same prev/curr double-insert step MIDI's and Guido's `TempoMap`
    // builders use: a `TempoMap` lookup finds the tempo active *at or before*
    // a beat, so the tempo that was in effect immediately before a change
    // has to be reasserted at the change's own beat position before the new
    // tempo is inserted there too — otherwise the lookup would report the
    // new tempo one instant too early.
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
}

// MARK: - ImporterProtocol

extension ABC.Importer: ImporterProtocol {

    // MARK: Internal Instance Properties

    internal var readableFileFormats: [FileFormat] {
        [.abc]
    }

    // MARK: Internal Instance Methods

    internal func read(from file: FileWrapper,
                       as fileFormat: FileFormat) throws(ABC.Error) -> [Work] {
        switch fileFormat {
        case .abc:
            guard let data = file.regularFileContents
            else { throw ABC.Error.parseFailure(nil) }

            let tunebook = try ABC.Parser().parse(data)

            return try convert(tunebook)

        default:
            throw ABC.Error.unsupportedFileFormat(fileFormat.displayName)
        }
    }
}

// MARK: - Sendable

extension ABC.Importer: Sendable {
}
