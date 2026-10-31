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

    // MARK: Private Type Aliases

    private typealias MIDIDirectives = (all: [ABCDirective],
                                        byVoice: [ABC.Voice.ID?: [ABCDirective]],
                                        header: [ABCDirective])

    // MARK: Private Type Methods

    private static func _convert(_ tune: ABCTune,
                                 fileHeader: [ABCHeaderEntry],
                                 version: ABCVersion?) throws(ABC.Error) -> Work {
        let results = try Walker().walk(tune, fileHeader: fileHeader)
        let directives = _findMIDIDirectives(tune, fileHeader: fileHeader)
        let parts = results.compactMap { result -> Part<BeatTime, Pitch>? in
            guard result.identity != nil || !_isEmptyImplicitVoice(result.context)
            else { return nil }

            return Part(name: determinePartName(result.identity),
                        noteTable: result.context.noteTable,
                        dynamicMap: _makeDynamicMap(result.context.dynamicEvents),
                        instrumentMap: _makeInstrumentMap(voiceID: result.identity?.id,
                                                          directives: directives))
        }
        let tempoEvents = results.flatMap(\.context.tempoEvents)

        return try Work(name: determineWorkName(tune),
                        content: .standardBeat(fillEmptyPartNames(parts), _makeTempoMap(tempoEvents)),
                        info: _makeInfo(tune,
                                        fileHeader: fileHeader,
                                        version: version))
    }

    // Normalization rewrites the tunebook's version to the current one, so
    // the version the file declared is read off the parsed tunebook first:
    // `A:` means something different in an ABC 2.0 file (see
    // `_makeInfo`).
    private static func _convert(_ tunebook: ABC.Tunebook) throws -> [Work] {
        let version = tunebook.version
        let (normalized, _) = ABC.Normalizer().normalize(tunebook)
        let (validated, issues) = try ABC.Validator().validate(normalized)

        guard issues.isEmpty
        else { throw ABC.Error.validationFailure(issues) }

        var works: [Work] = []

        for tune in validated.tunes {
            try works.append(_convert(tune,
                                      fileHeader: validated.fileHeader,
                                      version: version))
        }

        return works
    }

    // A tune's `%%MIDI` directives, grouped the way abc2midi applies them:
    // one in the body goes to the current voice — the one the last `V:`
    // field switched to, `nil` being the implicit voice — and one in a
    // header, where no voice is current yet, to every voice. `all` holds
    // them in the order written.
    private static func _findMIDIDirectives(_ tune: ABCTune,
                                            fileHeader: [ABCHeaderEntry]) -> MIDIDirectives {
        var all: [ABCDirective] = []
        var byVoice: [ABC.Voice.ID?: [ABCDirective]] = [:]
        var header: [ABCDirective] = []
        var currentID: ABC.Voice.ID?

        for entry in fileHeader + tune.header {
            if case let .directive(directive) = entry,
               _isMIDIDirective(directive) {
                all.append(directive)
                header.append(directive)
            }
        }

        for entry in tune.body {
            switch entry {
            case let .directive(directive) where _isMIDIDirective(directive):
                all.append(directive)
                byVoice[currentID, default: []].append(directive)

            case let .field(.voice(voice)):
                currentID = voice.id

            case let .symbols(symbols):
                for case let .inlineField(.voice(voice)) in symbols {
                    currentID = voice.id
                }

            default:
                break
            }
        }

        return (all, byVoice, header)
    }

    // The first of `directives` that `convert` makes something of.
    private static func _first<T>(in directives: [ABCDirective],
                                  _ convert: (ABCDirective) -> T?) -> T? {
        directives.lazy.compactMap(convert).first
    }

    private static func _isMIDIDirective(_ directive: ABCDirective) -> Bool {
        directive.name.stringValue.lowercased() == "midi"
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
                if event.mark == nil, event.beatTime != .zero {
                    dynamicMap.insert(time: event.beatTime,
                                      dynamic: prevDynamic)
                }

                dynamicMap.insert(time: event.beatTime,
                                  dynamic: event.dynamic,
                                  extras: event.mark.map {
                                      Extras(elements: [Extra(name: Extra.dynamicMark.name,
                                                              values: [.string($0)])])
                                  })
            }

            prevDynamic = event.dynamic
        }

        return dynamicMap
    }

    // The descriptive fields of the file header apply to every tune in the
    // file (§2.2.2), so they're read ahead of the tune's own header. The
    // first `T:` of the tune header is the title and any later one an
    // alternative title (§3.1.2); a `T:` in the body names a section of the
    // tune and isn't read. Every other repeated field adds to the ones
    // before it rather than replacing them (§3).
    //
    // `A:` named the lyricist in ABC 2.0 (§10.1) but is the (deprecated)
    // area in every other version. `Z:` credits a transcriber unless its
    // prefix says otherwise (§3.1.10): `abc-copyright` is the copyright of
    // the *transcription*, not the tune, and `abc-edited-by` names an
    // editor. The ABC 2.0 `%%abc-copyright`/`%%abc-edited-by` directives
    // `Z:` replaced read the same way. An `N:` field labeled as a
    // dedication (see `parseDedicationText(_:)`) is the dedication. A remark
    // field (`r:`) is a remark with no label; the other string fields are
    // remarks labeled with what the field holds.
    private static func _makeInfo(_ tune: ABCTune,
                                  fileHeader: [ABCHeaderEntry],
                                  version: ABCVersion?) -> Work.Info {
        var info = Work.Info()

        for entry in tune.header {
            guard case let .field(.tuneTitle(text)) = entry
            else { continue }

            if info.title == nil {
                info.title = text.stringValue
            } else {
                info.alternateTitles.append(text.stringValue)
            }
        }

        func addRemark(_ text: ABCText, _ label: String?) {
            if let remark = Remark(text: text.stringValue, label: label) {
                info.remarks.append(remark)
            }
        }

        func addTranscription(_ value: String) {
            if let text = _strippingPrefix("abc-copyright", from: value) {
                if let notice = RightsNotice(text: text, scope: .transcription) {
                    info.rights.append(notice)
                }
            } else if let name = _strippingPrefix("abc-edited-by", from: value) {
                if let credit = Credit(name: name, role: .editor) {
                    info.credits.append(credit)
                }
            } else if let credit = Credit(name: _strippingPrefix("abc-transcription", from: value) ?? value,
                                          role: .transcriber) {
                info.credits.append(credit)
            }
        }

        for entry in fileHeader + tune.header {
            switch entry {
            case let .directive(directive):
                switch directive.name.stringValue.lowercased() {
                case "abc-copyright":
                    addTranscription("abc-copyright " + directive.value)

                case "abc-edited-by":
                    addTranscription("abc-edited-by " + directive.value)

                default:
                    break
                }

            case let .field(.area(text)):
                if version?.major == 2, version?.minor == 0 {
                    if let credit = Credit(name: text.stringValue, role: .lyricist) {
                        info.credits.append(credit)
                    }
                } else {
                    addRemark(text, RemarkLabel.area)
                }

            case let .field(.book(text)):
                addRemark(text, RemarkLabel.book)

            case let .field(.composer(text)):
                if let credit = Credit(name: text.stringValue, role: .composer) {
                    info.credits.append(credit)
                }

            case let .field(.discography(text)):
                addRemark(text, RemarkLabel.discography)

            case let .field(.fileURL(text)):
                addRemark(text, RemarkLabel.fileURL)

            case let .field(.group(text)):
                addRemark(text, RemarkLabel.group)

            case let .field(.history(text)):
                addRemark(text, RemarkLabel.history)

            case let .field(.notes(text)):
                if info.dedication == nil,
                   let dedication = parseDedicationText(text.stringValue) {
                    info.dedication = dedication
                } else {
                    addRemark(text, RemarkLabel.notes)
                }

            case let .field(.origin(text)):
                addRemark(text, RemarkLabel.origin)

            case let .field(.remark(text)):
                addRemark(text, nil)

            case let .field(.rhythm(text)):
                addRemark(text, RemarkLabel.rhythm)

            case let .field(.source(text)):
                addRemark(text, RemarkLabel.source)

            case let .field(.transcription(text)):
                addTranscription(text.stringValue)

            default:
                break
            }
        }

        return info
    }

    // A voice's instrument comes from its own `%%MIDI voice`, `%%MIDI
    // program` and `%%MIDI channel` directives, or failing those from a
    // header's — the first of each kind; abc2midi would change instrument
    // where a later one is written, but here the first holds for the whole
    // tune. A `%%MIDI voice` directive that names this voice wins wherever
    // it's written (one naming another voice is skipped), and `%%MIDI
    // voice` wins over `%%MIDI program`. A `program` directive's own channel
    // token wins over a standalone `channel` directive, and that channel
    // applies whichever directive gave the instrument.
    //
    // `%%MIDI program` numbers count from `%%MIDI programbase`: 0 unless a
    // directive says 1, as in abc2midi, though the ABC standard counts from
    // 1. abc2midi keeps the last `programbase` it reads, so this does too.
    //
    // A `channel` directive with no instrument at all still produces an
    // entry, as `.vanilla`, so its `midiChannel` extra has somewhere to
    // live; an empty `InstrumentMap` would otherwise be indistinguishable
    // from "no MIDI directives at all" (see this type's own
    // `Instrument.vanilla` default).
    private static func _makeInstrumentMap(voiceID: ABC.Voice.ID?,
                                           directives: MIDIDirectives) -> InstrumentMap<BeatTime> {
        let own = directives.byVoice[voiceID] ?? []
        let programBase = directives.all.compactMap(convertToProgramBase).last ?? 0

        func first<T>(_ convert: (ABCDirective) -> T?) -> T? {
            _first(in: own, convert) ?? _first(in: directives.header, convert)
        }

        let namedVoice = voiceID.flatMap { voiceID in
            _first(in: directives.all) { convertToVoiceInstrument($0).flatMap { $0.voiceID == voiceID ? $0 : nil } }
        }
        let voice = namedVoice ?? first { convertToVoiceInstrument($0).flatMap { $0.voiceID == nil ? $0 : nil } }
        let program = first { convertToInstrument($0, programBase: programBase) }
        let channel = program?.channel ?? first(convertToChannel)
        var elements: [Extra] = []
        var instrument: Instrument = .vanilla

        if let voice {
            instrument = voice.instrument
            elements.append(Extra(name: Extra.midiProgram.name, values: [.int(voice.program)]))

            if let bank = voice.bank {
                elements.append(Extra(name: Extra.midiBank.name, values: [.int(bank)]))
            }
        } else if let program {
            instrument = program.instrument
            elements.append(Extra(name: Extra.midiProgram.name, values: [.int(program.program)]))
        }

        if let channel {
            elements.append(Extra(name: Extra.midiChannel.name, values: [.int(channel)]))
        }

        var instrumentMap = InstrumentMap<BeatTime>()

        if !elements.isEmpty {
            instrumentMap.insert(time: .zero, instrument: instrument, extras: Extras(elements: elements))
        }

        return instrumentMap
    }

    // The same prev/curr double-insert step MIDI's and Guido's `TempoMap`
    // builders use: a `TempoMap` lookup finds the tempo active *at or before*
    // a beat, so the tempo that was in effect immediately before a change
    // has to be reasserted at the change's own beat position before the new
    // tempo is inserted there too — otherwise the lookup would report the
    // new tempo one instant too early.
    private static func _makeTempoMap(_ events: [(beatTime: BeatTime, tempo: Tempo, text: String?)]) -> TempoMap {
        var tempoMap = TempoMap()
        var previousTempo: Tempo = .default

        for event in events.sorted(by: { $0.beatTime < $1.beatTime }) {
            if event.beatTime != .zero {
                tempoMap.insert(beatTime: event.beatTime, tempo: previousTempo)
            }

            let extras = event.text.map {
                Extras(elements: [Extra(name: Extra.tempoText.name, values: [.string($0)])])
            }

            tempoMap.insert(beatTime: event.beatTime, tempo: event.tempo, extras: extras)
            previousTempo = event.tempo
        }

        return tempoMap
    }

    // The rest of `value` after `prefix` and the whitespace following it,
    // or `nil` if `value` doesn't start with `prefix` as a whole word.
    private static func _strippingPrefix(_ prefix: String,
                                         from value: String) -> String? {
        guard value.hasPrefix(prefix)
        else { return nil }

        let rest = value.dropFirst(prefix.count)

        guard rest.isEmpty || rest.first?.isWhitespace == true
        else { return nil }

        return String(rest)
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
