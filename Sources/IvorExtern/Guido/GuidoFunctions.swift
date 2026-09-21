// © 2025–2026 John Gary Pusey (see LICENSE.md)

internal import IvorGuido
internal import IvorModel
internal import IvorTiming
internal import IvorTuning
internal import XestiTools

private import XestiNumbers

// MARK: Internal Functions

internal func convertToBeatDuration(_ duration: Guido.Duration) -> BeatDuration {
    BeatDuration(duration.numberValue * 4)
}

// `\intensity`'s `type` is an open string, matched against guidolib's own
// symbol table only at render time (see `GMNIntensity`'s doc comment), so
// only the ten standard dynamic names — matched case-insensitively — convert;
// anything else (an expressive marking like `"cresc."`, a typo, a dialect
// this vocabulary doesn't cover) is left unrecognized rather than guessed at.
internal func convertToDynamic(_ type: String) -> Dynamic? {
    switch type.lowercased() {
    case "pppp":
        .pppp

    case "ppp":
        .ppp

    case "pp":
        .pp

    case "p":
        .p

    case "mp":
        .mp

    case "mf":
        .mf

    case "f":
        .f

    case "ff":
        .ff

    case "fff":
        .fff

    case "ffff":
        .ffff

    default:
        nil
    }
}

// Reverse of `convertToBeatDuration(_:)`: a beat duration (quarter note = 1
// beat) becomes a fraction of a whole note. `GMNDuration.init?` accepts any
// non-zero rational and reduces it itself, so unlike ABC there is no
// power-of-2 constraint to work around — this only fails when `duration`
// isn’t rational at all or reduces to a non-positive numerator, neither of
// which a real note/rest duration produces.
internal func convertToGuidoDuration(_ duration: BeatDuration) -> GMNDuration? {
    let numberValue = duration.numberValue

    guard numberValue.isRational,
          numberValue.numerator > 0
    else { return nil }

    return GMNDuration(numerator: numberValue.numerator.uintValue,
                       denominator: numberValue.denominator.uintValue * 4)
}

// Reverse of `convertToDynamic(_:)`: only the ten standard dynamic levels
// have a discrete `\intensity` type. A `Dynamic` produced by ramp
// interpolation — an intermediate rational that doesn’t exactly match one of
// the ten levels — has no type to convert to and is omitted rather than
// rounded to the nearest one.
internal func convertToGuidoIntensity(_ dynamic: Dynamic) -> GMNIntensity? {
    let type: String? = switch dynamic {
    case .pppp:
        "pppp"

    case .ppp:
        "ppp"

    case .pp:
        "pp"

    case .p:
        "p"

    case .mp:
        "mp"

    case .mf:
        "mf"

    case .f:
        "f"

    case .ff:
        "ff"

    case .fff:
        "fff"

    case .ffff:
        "ffff"

    default:
        nil
    }

    guard let type
    else { return nil }

    return GMNIntensity(type: type)
}

// The model has no field to store pitch spelling other than through
// `pitchClass`, so this reads it directly rather than inventing an
// enharmonic choice. `Guido.Pitch.Name`’s German/solfège spellings (`cis`,
// `re`, …) are import-direction aliases only — export always uses the plain
// letter names `a`...`g`.
internal func convertToGuidoPitch(_ pitch: Pitch) throws(Guido.Error) -> GMNPitch {
    let octaveValue = pitch.octave.intValue - 3

    guard let octave = GMNPitch.Octave(intValue: octaveValue)
    else { throw Guido.Error.unrecognizedPitchOctave(octaveValue) }

    return GMNPitch(name: _convertToGuidoPitchName(pitch.pitchClass.letter),
                    accidental: _convertToGuidoPitchAccidental(pitch.pitchClass.accidental),
                    octave: octave)
}

// The reverse of `Guido.Importer.Walker._articulationExtra(_:)`/
// `_ornamentExtra(_:)`/`_slurExtra(_:_:)` — one Tier 1 flag (see
// `EXTRAS_CANDIDATES.md`) converts to one Guido tag, scoped over `body`
// (the note/chord symbol(s) it covers). Every `GMNArticulation`/
// `GMNOrnament` kind but `\stacc` only has guidolib's bracketing `.whole`
// form — no open-span `Begin`/`End` alternative — so `body:` (not a
// sibling `Begin`/`End` pair) is this vocabulary's one uniform wrapping
// shape; `\breathMark`/`\fingering` take the same shape for consistency,
// even though guidolib's own template doesn't require it of them. Guido
// has no free-text escape hatch the way ABC's open decoration names or
// MusicXML's `other…` cases do, so the `articulation` catch-all extra has
// nothing to convert to here and is silently dropped on export — a real,
// documented asymmetry, not a bug: Guido's own closed vocabulary is simply
// narrower than what this vocabulary's catch-all needs to hold.
internal func convertToGuidoTag(_ extra: Extra, body: [GMNSymbol]) -> GMNTag? {
    switch extra.name {
    case Extra.accent.name:
        GMNArticulation(kind: .accent, body: body).map { GMNTag.articulation($0) }

    case Extra.marcato.name:
        GMNArticulation(kind: .marcato, body: body).map { GMNTag.articulation($0) }

    case Extra.tenuto.name:
        GMNArticulation(kind: .tenuto, body: body).map { GMNTag.articulation($0) }

    case Extra.staccato.name:
        GMNArticulation(kind: .staccato, body: body).map { GMNTag.articulation($0) }

    case Extra.fermata.name:
        GMNArticulation(kind: .fermata, body: body).map { GMNTag.articulation($0) }

    case Extra.harmonic.name:
        GMNArticulation(kind: .harmonic, body: body).map { GMNTag.articulation($0) }

    case Extra.pizzicato.name:
        GMNArticulation(kind: .pizzicato, body: body).map { GMNTag.articulation($0) }

    case Extra.upBow.name:
        GMNArticulation(kind: .bow, type: "up", body: body).map { GMNTag.articulation($0) }

    case Extra.downBow.name:
        GMNArticulation(kind: .bow, type: "down", body: body).map { GMNTag.articulation($0) }

    case Extra.trill.name:
        GMNOrnament(kind: .trill, body: body).map { GMNTag.ornament($0) }

    case Extra.mordent.name:
        GMNOrnament(kind: .mordent, body: body).map { GMNTag.ornament($0) }

    case Extra.turn.name:
        GMNOrnament(kind: .turn, body: body).map { GMNTag.ornament($0) }

    case Extra.breathMark.name:
        .breathMark(GMNBreathMark(body: body))

    case Extra.fingering.name:
        if case let .string(text)? = extra.values.first {
            GMNTag.fingering(GMNFingering(text: text, body: body))
        } else {
            nil
        }

    default:
        nil
    }
}

// The `bpm` metronome specification always uses a quarter note as the beat
// unit — the same "quarter note = 1 beat" convention `convertToTempo(_:)`
// assumes on import — so the reverse conversion is just `tempo`'s own value.
internal func convertToGuidoTempo(_ tempo: Tempo, text: String? = nil) -> GMNTempo? {
    guard let unit = GMNTempo.Metronome.BeatUnit(1, 4)
    else { return nil }

    return GMNTempo(tempo: text ?? "\(tempo.uintValue)",
                    metronome: .rate(unit: unit,
                                     beats: Int(tempo.uintValue)))
}

// `\instrument`'s own name always wins over its `MIDI` program-number hint —
// the name is what a listener actually recognizes, and guidolib treats it as
// the tag's one non-omissible parameter. `MIDI` only stands in when a name
// was never written, which the required-parameter promotion rule (see
// `GMNInstrument`'s doc comment) makes impossible in a well-formed score, but
// this still degrades gracefully rather than assuming it.
internal func convertToInstrument(_ instrument: GMNInstrument) -> Instrument {
    guard instrument.instrumentName.isEmpty
    else { return Instrument(stringValue: instrument.instrumentName) ?? .vanilla }

    guard let midi = instrument.midi
    else { return .vanilla }

    return Instrument(stringValue: generalMIDIInstrumentName(program: midi)) ?? .vanilla
}

internal func convertToStandardPitch(_ pitch: Guido.Pitch) throws(Guido.Error) -> Pitch {
    try Pitch(pitchClass: _convertToStandardPitchClass(pitch.name,
                                                       pitch.accidental),
              octave: _convertToStandardPitchOctave(pitch.octave.intValue))
}

// The `.equivalence` form (`1/4=1/8.`) states a note-equivalence with no
// absolute rate; nothing here can turn that into a beats-per-minute value,
// so it — and a `bpm` rounding to zero or less — contribute nothing.
internal func convertToTempo(_ metronome: GMNTempo.Metronome) -> Tempo? {
    guard case let .rate(unit, beats) = metronome,
          unit.denominator != 0
    else { return nil }

    let quarterBPM = Double(beats) * Double(unit.numerator) / Double(unit.denominator) * 4

    guard quarterBPM > 0
    else { return nil }

    return Tempo(uintValue: UInt(quarterBPM.rounded()))
}

internal func determinePartName(_ voice: Guido.Voice) -> String {
    for tag in _findTags(voice.symbols) {
        if case let .instrument(instrument) = tag {
            return instrument.instrumentName
        }
    }

    return ""
}

internal func determineWorkName(_ score: Guido.Score) -> String {
    guard let voice = score.voices.first
    else { return "" }

    let titles: [String] = _findTags(voice.symbols).compactMap {
        guard case let .titleBlock(block) = $0,
              block.kind == .title
        else { return nil }

        return block.text
    }

    return titles.joined(separator: ": ")
}

// MARK: Private Functions

// Guido Music Notation has no explicit natural sign, so a natural pitch
// converts to `.omitted` rather than to some notated-but-inert form — an
// omitted accidental already means the unmodified pitch (see
// `GMNPitch.Accidental.omitted`).
private func _convertToGuidoPitchAccidental(_ accidental: Pitch.Accidental) -> GMNPitch.Accidental {
    switch accidental {
    case .doubleFlat:
        .doubleFlat

    case .doubleSharp:
        .doubleSharp

    case .flat:
        .flat

    case .natural:
        .omitted

    case .sharp:
        .sharp
    }
}

private func _convertToGuidoPitchName(_ letter: Pitch.Letter) -> GMNPitch.Name {
    switch letter {
    case .a:
        .a

    case .b:
        .b

    case .c:
        .c

    case .d:
        .d

    case .e:
        .e

    case .f:
        .f

    case .g:
        .g
    }
}

private func _convertToStandardPitchClass(_ gpName: Guido.Pitch.Name,
                                          _ gpAccidental: Guido.Pitch.Accidental) throws(Guido.Error) -> PitchClass {
    let letter: Pitch.Letter = switch gpName {
    case .a:
        .a

    case .b:
        .b

    case .c:
        .c

    case .d:
        .d

    case .e:
        .e

    case .empty:
        throw Guido.Error.unrecognizedPitchName(gpName)

    case .f:
        .f

    case .g:
        .g
    }

    let accidental: Pitch.Accidental = switch gpAccidental {
    case .doubleFlat:
        .doubleFlat

    case .doubleSharp:
        .doubleSharp

    case .flat:
        .flat

    case .natural:
        .natural

    case .sharp:
        .sharp
    }

    return PitchClass(letter: letter,
                      accidental: accidental)
}

private func _convertToStandardPitchOctave(_ gpOctave: Int) throws(Guido.Error) -> Pitch.Octave {
    guard let octave = Pitch.Octave(intValue: gpOctave + 3)
    else { throw Guido.Error.unrecognizedPitchOctave(gpOctave) }

    return octave
}

// Recursively collects every tag in `symbols`, including those nested
// inside a chord segment or another tag's body. Used only to determine work
// and part names — metadata the walk never surfaces on its own (it builds a
// note table, not a tag stream), so it is read from the validated,
// pre-walk AST instead.
private func _findTags(_ symbols: [Guido.Symbol]) -> [Guido.Tag] {
    var tags: [Guido.Tag] = []

    for symbol in symbols {
        switch symbol {
        case let .chord(chord):
            for segment in chord.segments {
                tags += _findTags(segment.symbols)
            }

        case let .tag(tag):
            tags.append(tag)
            tags += _findTags(tag.body)

        default:
            break
        }
    }

    return tags
}
