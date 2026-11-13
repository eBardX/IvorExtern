// © 2025–2026 John Gary Pusey (see LICENSE.md)

internal import Foundation
internal import IvorABC
internal import IvorModel
internal import IvorTiming
internal import IvorTuning
internal import XestiTools

private import IvorGeneralMIDI
private import IvorMIDI
private import XestiNumbers

// MARK: Internal Functions

// Reverse of `convertToDynamic(_:)`: only the ten standard dynamic levels
// have a discrete ABC decoration name. A `Dynamic` produced by ramp
// interpolation — an intermediate rational that doesn't exactly match one
// of the ten levels — has no name to convert to and is omitted rather than
// rounded to the nearest one.
internal func convertToABCDecorationName(_ dynamic: Dynamic) -> ABCDecoration.Name? {
    let name: String? = switch dynamic {
    case .f:
        "f"

    case .ff:
        "ff"

    case .fff:
        "fff"

    case .ffff:
        "ffff"

    case .mf:
        "mf"

    case .mp:
        "mp"

    case .p:
        "p"

    case .pp:
        "pp"

    case .ppp:
        "ppp"

    case .pppp:
        "pppp"

    default:
        nil
    }

    guard let name
    else { return nil }

    return ABCDecoration.Name(stringValue: name)
}

// The reverse of `convertToArticulationExtra(_:)` — one canonical ABC
// decoration name per Tier 1 flag. `plus`/`snap` both read as `.pizzicato`
// on import (ABC has no single generic pizzicato word), so this picks
// `snap` (the more common of the two markings) as the one write direction;
// the `plus`/`snap` distinction itself is lost on a `.pizzicato` round
// trip, an accepted simplification given ABC's own vocabulary split.
internal func convertToABCDecorationName(_ extra: Extra) -> ABCDecoration.Name? {
    let name: String? = switch extra.name {
    case Extra.accent.name:
        "accent"

    case Extra.breathMark.name:
        "breath"

    case Extra.downBow.name:
        "downbow"

    case Extra.fermata.name:
        "fermata"

    case Extra.harmonic.name:
        "harmonic"

    case Extra.marcato.name:
        "marcato"

    case Extra.mordent.name:
        "mordent"

    case Extra.pizzicato.name:
        "snap"

    case Extra.staccato.name:
        "staccato"

    case Extra.tenuto.name:
        "tenuto"

    case Extra.trill.name:
        "trill"

    case Extra.turn.name:
        "turn"

    case Extra.upBow.name:
        "upbow"

    default:
        nil
    }

    guard let name
    else { return nil }

    return ABCDecoration.Name(stringValue: name)
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

// The inverse of `convertToTempo(_:)`. The tempo keeps its own unit: a
// plain or dotted note value is written as one length (`Q:3/8=90`), and
// any other unit as ABC's compound form (§3.1.8), the summed lengths
// standing for one beat (`Q:1/4 3/8=40` for a unit of 5/8). See
// `_abcTempoLengths(_:)` for how the lengths are chosen. A unit with no such
// spelling (a triplet quarter note, say) is restated in quarter notes. ABC
// rates are whole numbers, so a fractional rate is rounded (see
// `roundedTempoRate(_:)`).
internal func convertToABCTempo(_ tempo: Tempo, text: String? = nil) -> ABCTempo? {
    if let lengths = _abcTempoLengths(tempo.unit) {
        return ABCTempo(lengths: lengths,
                        rate: roundedTempoRate(tempo),
                        text: text)
    }

    let restated = tempo.restated(in: .quarter)

    guard let quarterLength = ABCLength(numerator: 1, denominator: 4)
    else { return nil }

    return ABCTempo(lengths: [quarterLength],
                    rate: roundedTempoRate(restated),
                    text: text)
}

// The Tier 1 bare-flag articulation/ornament names shared with Guido's
// closed `Kind` enums and MusicXML's plain articulation/ornament/technical
// cases — see the "Tier 1 — closed, shared-name bare flags" list in
// `EXTRAS_CANDIDATES.md`. Matched case-insensitively against ABC's own
// recommended decoration vocabulary (ABC 2.1 §4.16.1); anything outside
// this set (a genuine off-scale dynamic mark like `sfz`, or an articulation
// word this list doesn't cover) is left for the caller to route elsewhere.
internal func convertToArticulationExtra(_ name: ABCDecoration.Name) -> Extra? {
    switch name.stringValue.lowercased() {
    case "accent",
         "emphasis":
        .accent

    case "breath":
        .breathMark

    case "downbow":
        .downBow

    case "fermata",
         "invertedfermata":
        .fermata

    case "harmonic",
         "open":
        .harmonic

    case "lowermordent",
         "mordent",
         "uppermordent":
        .mordent

    case "marcato":
        .marcato

    case "plus",
         "snap":
        .pizzicato

    case "staccato":
        .staccato

    case "tenuto":
        .tenuto

    case "trill":
        .trill

    case "turn":
        .turn

    case "upbow":
        .upBow

    default:
        nil
    }
}

// An ABC duration is a fraction of a whole note, as a beat duration is.
internal func convertToBeatDuration(_ duration: ABC.Duration) throws(ABC.Error) -> BeatDuration {
    BeatDuration(duration.numberValue)
}

// A standalone `%%MIDI channel n` directive — no `program` token — sets the
// MIDI channel without implying any instrument assignment, per
// `abc2midi.txt`. `n` is 1–16, the same convention `MXLMidi16`/`MIDI.
// Channel` already use elsewhere.
internal func convertToChannel(_ directive: ABCDirective) -> Int? {
    guard directive.name.stringValue.lowercased() == "midi"
    else { return nil }

    let tokens = directive.value.split(whereSeparator: \.isWhitespace)

    guard tokens.count == 2,
          tokens[0].lowercased() == "channel",
          let channel = Int(tokens[1]),
          (1...16).contains(channel)
    else { return nil }

    return channel
}

// A decoration's `name` is open, matched against a rendering program's own
// symbol table only when the score is played (see `ABCDecoration.Name`'s
// doc comment), so only the ten standard dynamic names — matched
// case-insensitively — convert; anything else (an ornament, an articulation,
// a dialect this vocabulary doesn't cover) is left unrecognized rather than
// guessed at.
internal func convertToDynamic(_ name: ABCDecoration.Name) -> Dynamic? {
    switch name.stringValue.lowercased() {
    case "f":
        .f

    case "ff":
        .ff

    case "fff":
        .fff

    case "ffff":
        .ffff

    case "mf":
        .mf

    case "mp":
        .mp

    case "p":
        .p

    case "pp":
        .pp

    case "ppp":
        .ppp

    case "pppp":
        .pppp

    default:
        nil
    }
}

// abc2midi's `%%MIDI program [channel] program-number` directive is the
// usual way to give an ABC voice an instrument — ABC itself has no
// built-in instrument concept. `ABCDirective.Name` only recognizes a
// handful of standard directive names with typed payloads (see its doc
// comment), so a `MIDI` directive's own `program`/channel/program-number
// sub-syntax is never parsed upstream; this hand-parses it out of the raw
// value text instead. The optional leading MIDI channel number, when
// written, is the middle token between `program` and the trailing program
// number — surfaced as `channel` for a `midiChannel` extra (see
// `Extra+Ivor.swift`); `nil` when the directive omits it.
//
// `program-number` counts from `programBase` (see
// `convertToProgramBase(_:)`). abc2midi has counted from 0 since 2003, the
// MIDI wire value, but its old documentation said 1–128, and the ABC
// standard followed that; abc2midi's `CHANGES` (June 2 2017) tells the
// story. The returned `program` is always the 1–128 General MIDI number,
// as the `midiProgram` extra holds it.
internal func convertToInstrument(_ directive: ABCDirective,
                                  programBase: Int) -> (instrument: Instrument, channel: Int?, program: Int)? {
    guard directive.name.stringValue.lowercased() == "midi"
    else { return nil }

    let tokens = directive.value.split(whereSeparator: \.isWhitespace)

    guard let keyword = tokens.first,
          keyword.lowercased() == "program",
          let programToken = tokens.last,
          let number = Int(programToken),
          case let program = number - programBase + 1,
          let midiProgram = UInt(exactly: program).flatMap({ MIDIProgram(uintValue: $0) }),
          let instrument = Instrument(stringValue: GM1Instrument(program: midiProgram).name)
    else { return nil }

    let channel = tokens.count == 3 ? Int(tokens[1]) : nil

    return (instrument, channel, program)
}

// abc2midi's `%%MIDI programbase n`, which says whether `%%MIDI program`
// numbers count from 0 or 1. Like abc2midi, any `n` but 0 means 1.
internal func convertToProgramBase(_ directive: ABCDirective) -> Int? {
    guard directive.name.stringValue.lowercased() == "midi"
    else { return nil }

    let tokens = directive.value.split(whereSeparator: \.isWhitespace)

    guard tokens.count == 2,
          tokens[0].lowercased() == "programbase",
          let base = Int(tokens[1])
    else { return nil }

    return base == 0 ? 0 : 1
}

internal func convertToStandardPitch(_ pitch: ABC.Pitch) throws(ABC.Error) -> Pitch {
    try Pitch(pitchClass: _convertToStandardPitchClass(pitch.letter,
                                                       pitch.accidental),
              octave: _convertToStandardPitchOctave(pitch.octave))
}

// The `Q:` field's rate, with its beat as the tempo's unit. Per §3.1.8 of
// the ABC 2.1 standard, a compound beat (more than one entry in `lengths`,
// e.g. `Q:1/4 3/8 1/4 3/8=40`) means "play as if the summed length were the
// beat", so the unit is the sum of the lengths (here, 5/4) —
// `ABCNormalizer` only resolves the deprecated `Q:Cn=rate`/bare `Q:rate`
// forms to a single `lengths` entry (the bare form's being the `L:` unit),
// not this valid modern compound-beat form, so summing here is still
// necessary. A `Q:` with no `rate` (text only, e.g. `Q:"Allegro"`) has an
// empty `lengths` and returns `nil`.
internal func convertToTempo(_ tempo: ABCTempo) -> Tempo? {
    guard let rate = tempo.rate,
          !tempo.lengths.isEmpty
    else { return nil }

    let unit = tempo.lengths
        .map { Number(numerator: $0.numerator, denominator: $0.denominator) }
        .reduce(Number(0), +)

    return Tempo(rate: Number(rate),
                 unit: BeatDuration(unit))
}

// ABC 2.1's own `%%MIDI voice [ID] [instrument=n [bank=m]] [mute]`
// directive (§11.2), which assigns an instrument to one voice — the voice
// `ID` names or, without one, the current voice. Both numbers count from
// 1, whatever `%%MIDI programbase` says (abc2midi doesn't read this
// directive at all): `n` is the 1–128 General MIDI number, as the
// `midiProgram` extra holds it, but `bank` comes back as `m − 1`, the
// 0-based combined Bank Select value the `midiBank` extra holds, so the
// default bank 1 is bank 0. A directive with no `instrument=` (just
// `mute`, say) assigns nothing and gives `nil`; `mute` itself is ignored,
// as there's nowhere to keep it, and so is a `bank=` out of range.
internal func convertToVoiceInstrument(_ directive: ABCDirective) -> ABC.VoiceInstrument? {
    guard directive.name.stringValue.lowercased() == "midi"
    else { return nil }

    var tokens = directive.value.split(whereSeparator: \.isWhitespace)[...]

    guard tokens.popFirst()?.lowercased() == "voice"
    else { return nil }

    var voiceID: ABC.Voice.ID?

    if let first = tokens.first,
       !first.contains("="),
       first.lowercased() != "mute" {
        voiceID = ABC.Voice.ID(stringValue: String(first))
        tokens.removeFirst()
    }

    var settings: [String: Int] = [:]

    for token in tokens {
        let pair = token.split(separator: "=", maxSplits: 1)

        if pair.count == 2,
           let value = Int(pair[1]) {
            settings[pair[0].lowercased()] = value
        }
    }

    guard let program = settings["instrument"],
          let midiProgram = UInt(exactly: program).flatMap({ MIDIProgram(uintValue: $0) }),
          let instrument = Instrument(stringValue: GM1Instrument(program: midiProgram).name)
    else { return nil }

    let bank = settings["bank"].flatMap { (1...16_384).contains($0) ? $0 - 1 : nil }

    return ABC.VoiceInstrument(bank: bank,
                               instrument: instrument,
                               program: program,
                               voiceID: voiceID)
}

// A voice name's `\n` is abcm2ps's line-break convention for stacking a
// staff label over two lines (`nm="Tenor\nSax"`), not text — the parser
// keeps it as a literal backslash and `n` — so each break collapses to a
// single space, like any other run of whitespace, for a one-line part
// name. A voice with no name of its own falls back to its id, unless that
// id is a bare voice number (`1`, `V2`): those say nothing a positional
// "Voice N" from `fillEmptyPartNames` doesn't, so the part is left
// unnamed for it to number alongside every other unnamed part.
internal func determinePartName(_ voice: ABC.Voice?) -> String {
    guard let voice
    else { return "" }

    guard let name = voice.name ?? voice.subname
    else { return _isVoiceNumber(voice.id.stringValue) ? "" : normalizeName(voice.id.stringValue) }

    return normalizeName(name.replacingOccurrences(of: "\\n", with: " "))
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

// The lengths of a `Q:` field's beat for a tempo unit: the unit itself if
// it's a plain or dotted note value, otherwise the fewest plain or dotted
// lengths (at most four, as ABC allows) that sum to it, preferring the most
// even split — so 5/8 is `1/4 3/8` rather than `1/2 1/8` — written shortest
// first. `nil` if no such lengths exist, as for a unit whose denominator
// isn't a power of two.
private func _abcTempoLengths(_ unit: BeatDuration) -> [ABCLength]? {
    let value = unit.numberValue

    guard value.isRational,
          value.numerator > 0
    else { return nil }

    let numerator = value.numerator.uintValue
    let denominator = value.denominator.uintValue

    guard denominator.nonzeroBitCount == 1,
          denominator <= 512
    else { return nil }

    if plainOrDottedNoteValue(unit) != nil {
        return ABCLength(numerator: numerator, denominator: denominator).map { [$0] }
    }

    // Every plain or dotted length from a breve down, in 512ths of a whole
    // note, the finest an `ABCLength` can be.
    let target = numerator * (512 / denominator)
    var candidates: [UInt] = []
    var plain: UInt = 1_024

    while plain > 0 {
        candidates.append(plain)

        if plain > 1 {
            candidates.append(plain * 3 / 2)
        }

        plain /= 2
    }

    candidates.sort()

    for count in 2...4 {
        var best: [UInt]?

        _searchTempoLengths(candidates, target, count, [], &best)

        if let best {
            return best.compactMap { ABCLength(numerator: $0, denominator: 512) }
        }
    }

    return nil
}

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

private func _isVoiceNumber(_ id: String) -> Bool {
    let digits = id.hasPrefix("V") || id.hasPrefix("v") ? id.dropFirst() : id[...]

    return !digits.isEmpty && digits.allSatisfy { $0.isASCII && $0.isNumber }
}

// Collects in `best` the nondecreasing run of exactly `pieces` candidates
// summing to `remaining` whose largest is smallest.
private func _searchTempoLengths(_ candidates: [UInt],
                                 _ remaining: UInt,
                                 _ pieces: Int,
                                 _ chosen: [UInt],
                                 _ best: inout [UInt]?) {
    guard pieces > 0
    else {
        if remaining == 0,
           let last = chosen.last,
           best.map({ last < ($0.last ?? .max) }) ?? true {
            best = chosen
        }

        return
    }

    let lowest = chosen.last ?? 0

    for candidate in candidates where candidate >= lowest && candidate <= remaining {
        _searchTempoLengths(candidates,
                            remaining - candidate,
                            pieces - 1,
                            chosen + [candidate],
                            &best)
    }
}
