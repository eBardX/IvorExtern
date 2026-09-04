// © 2025–2026 John Gary Pusey (see LICENSE.md)

internal import IvorABC
internal import IvorModel
internal import IvorTiming
internal import IvorTuning

private import XestiNumbers

// MARK: Internal Functions

// Reverse of `convertToDynamic(_:)`: only the ten standard dynamic levels
// have a discrete ABC decoration name. A `Dynamic` produced by ramp
// interpolation — an intermediate rational that doesn't exactly match one
// of the ten levels — has no name to convert to and is omitted rather than
// rounded to the nearest one.
internal func convertToABCDecorationName(_ dynamic: Dynamic) -> ABCDecoration.Name? {
    let name: String? = switch dynamic {
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

    guard let name
    else { return nil }

    return ABCDecoration.Name(stringValue: name)
}

// Converts an absolute duration (in beats, i.e. a multiplier of the unit
// note length `L:1/4` this exporter always writes) into an `ABCLength`, or
// `nil` if the reduced fraction's denominator isn't a power of 2 in
// 1...512 — the caller is responsible for tuplet-scaling a duration first
// when its plain reduced form doesn't qualify.
internal func convertToABCLength(_ duration: BeatDuration) -> ABCLength? {
    let numberValue = duration.numberValue

    guard numberValue.isRational
    else { return nil }

    let numerator = numberValue.numerator.uintValue

    guard numerator > 0
    else { return nil }

    return ABCLength(numerator: numerator,
                     denominator: numberValue.denominator.uintValue)
}

// The model carries no octave below C0, but `ABCPitch.Octave` only spans
// C0...C9 (§4.1), so a `Pitch` at octave −1 has no ABC representation.
internal func convertToABCPitch(_ pitch: Pitch) throws(ABC.Error) -> ABCPitch {
    guard pitch.octave.intValue >= 0,
          let octave = ABCPitch.Octave(uintValue: UInt(pitch.octave.intValue))
    else { throw ABC.Error.unrepresentablePitch(pitch.description) }

    return ABCPitch(letter: _convertToABCPitchLetter(pitch.letter),
                    accidental: _convertToABCPitchAccidental(pitch.accidental),
                    octave: octave)
}

// The inverse of `convertToTempo(_:)`. Always anchors the beat to a quarter
// note (`Q:1/4=rate`), matching the `L:1/4` unit note length this exporter
// always writes, so the two fields stay mutually consistent and round-trip
// exactly through `convertToTempo(_:)`'s own quarter-note resolution.
internal func convertToABCTempo(_ tempo: Tempo) -> ABCTempo? {
    guard let quarterLength = ABCLength(numerator: 1, denominator: 4)
    else { return nil }

    return ABCTempo(lengths: [quarterLength],
                    rate: tempo.uintValue,
                    text: nil)
}

internal func convertToBeatDuration(_ duration: ABC.Duration) throws(ABC.Error) -> BeatDuration {
    BeatDuration(duration.numberValue * 4)
}

// A decoration's `name` is open, matched against a rendering program's own
// symbol table only when the score is played (see `ABCDecoration.Name`'s
// doc comment), so only the ten standard dynamic names — matched
// case-insensitively — convert; anything else (an ornament, an articulation,
// a dialect this vocabulary doesn't cover) is left unrecognized rather than
// guessed at.
internal func convertToDynamic(_ name: ABCDecoration.Name) -> Dynamic? {
    switch name.stringValue.lowercased() {
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

// abc2midi's `%%MIDI program [channel] program-number` directive is the only
// mechanism this format gives for instrument assignment — ABC itself has no
// built-in instrument concept. `ABCDirective.Name` only recognizes a
// handful of standard directive names with typed payloads (see its doc
// comment), so a `MIDI` directive's own `program`/channel/program-number
// sub-syntax is never parsed upstream; this hand-parses it out of the raw
// value text instead. The optional leading MIDI channel number, when
// written, is simply the token this skips past to reach the trailing
// program number — the one that always matters for instrument choice.
internal func convertToInstrument(_ directive: ABCDirective) -> Instrument? {
    guard directive.name.stringValue.lowercased() == "midi"
    else { return nil }

    let tokens = directive.value.split(whereSeparator: \.isWhitespace)

    guard let keyword = tokens.first,
          keyword.lowercased() == "program",
          let programToken = tokens.last,
          let program = Int(programToken)
    else { return nil }

    return Instrument(stringValue: generalMIDIInstrumentName(program: program))
}

internal func convertToStandardPitch(_ pitch: ABC.Pitch) throws(ABC.Error) -> Pitch {
    try Pitch(pitchClass: _convertToStandardPitchClass(pitch.letter,
                                                       pitch.accidental),
              octave: _convertToStandardPitchOctave(pitch.octave))
}

// The `Q:` field's rate, resolved to quarter-note beats per minute. Per
// §3.1.8 of the ABC 2.1 standard, a compound beat (more than one entry in
// `lengths`, e.g. `Q:1/4 3/8 1/4 3/8=40`) means "play as if the summed
// length were the beat" — `ABCNormalizer` only resolves the deprecated
// `Q:Cn=rate`/bare `Q:rate` forms to a single `lengths` entry, not this
// valid modern compound-beat form, so summing here is still necessary. A
// `Q:` with no `rate` (text only, e.g. `Q:"Allegro"`) has an empty
// `lengths` and returns `nil`.
internal func convertToTempo(_ tempo: ABCTempo) -> Tempo? {
    guard let rate = tempo.rate,
          !tempo.lengths.isEmpty
    else { return nil }

    let beatFraction = tempo.lengths.reduce(0.0) { $0 + Double($1.numerator) / Double($1.denominator) }
    let quarterBPM = (Double(rate) * beatFraction * 4).rounded()

    guard let uintValue = UInt(exactly: quarterBPM)
    else { return nil }

    return Tempo(uintValue: uintValue)
}

internal func determinePartName(_ voice: ABC.Voice?) -> String {
    guard let voice
    else { return "" }

    return voice.name ?? voice.subname ?? voice.id.stringValue
}

internal func determineWorkName(_ tune: ABCTune) -> String {
    for entry in tune.header {
        if case let .field(.tuneTitle(title)) = entry {
            return title.stringValue
        }
    }

    return ""
}

// MARK: Private Functions

private func _convertToABCPitchAccidental(_ accidental: Pitch.Accidental) -> ABCPitch.Accidental {
    switch accidental {
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
}

private func _convertToABCPitchLetter(_ letter: Pitch.Letter) -> ABCPitch.Letter {
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

private func _convertToStandardPitchClass(_ apLetter: ABC.Pitch.Letter,
                                          _ apAccidental: ABC.Pitch.Accidental) throws(ABC.Error) -> PitchClass {
    let letter: Pitch.Letter = switch apLetter {
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

    let accidental: Pitch.Accidental = switch apAccidental {
    case .doubleFlat:
        .doubleFlat

    case .doubleSharp:
        .doubleSharp

    case .flat:
        .flat

    case .natural:
        .natural

    case .omitted:
        throw ABC.Error.unrecognizedPitchAccidental(apAccidental)

    case .sharp:
        .sharp
    }

    return PitchClass(letter: letter,
                      accidental: accidental)
}

private func _convertToStandardPitchOctave(_ apOctave: ABC.Pitch.Octave) throws(ABC.Error) -> Pitch.Octave {
    guard let octave = Pitch.Octave(intValue: Int(apOctave.uintValue))
    else { throw ABC.Error.unrecognizedPitchOctave(apOctave) }

    return octave
}
