// © 2025–2026 John Gary Pusey (see LICENSE.md)

internal import IvorModel
internal import IvorMusicXML
internal import IvorTiming
internal import IvorTuning

private import XestiNumbers
private import XestiTools

// MARK: Internal Functions

internal func convertToBeatDuration(_ duration: MusicXML.Duration) -> BeatDuration {
    BeatDuration(duration.numberValue * 4)
}

internal func convertToBeatTime(_ duration: MusicXML.Duration) -> BeatTime {
    BeatTime(duration.numberValue * 4)
}

// A `<direction>`'s notated dynamics mark, expressed as our own `Dynamic`
// scale — the first recognized `MXLDynamics.Item` across every
// `<direction-type><dynamics>` this direction carries, since a direction
// realistically states at most one dynamic level at a time.
internal func convertToDynamic(_ direction: MXLDirection) -> Dynamic? {
    for kind in direction.kind {
        guard case let .dynamics(marks) = kind.content
        else { continue }

        for mark in marks {
            for item in mark.items {
                if let dynamic = convertToDynamic(item) {
                    return dynamic
                }
            }
        }
    }

    return nil
}

// `Dynamic` only names the ten levels from `pppp` through `ffff`, so a mark
// beyond either end (`ffff`/`fffff`/`ffffff`, `pppp`/`ppppp`/`pppppp`)
// clamps to its nearest named level, and a compound accent-then-level mark
// (`fp`, `sfzp`, `pf`, …) converts to the level it settles on rather than
// its initial accent. `n` (niente, "fade to nothing") converts to silence.
// A momentary accent with no implied settled level (`sf`, `sfz`, `fz`,
// `rf`, `rfz`) and free-text `otherDynamics` (no fixed vocabulary to read a
// level from) are left unrecognized rather than guessed at.
internal func convertToDynamic(_ item: MXLDynamics.Item) -> Dynamic? {
    switch item {
    case .pppp,
         .ppppp,
         .pppppp:
        .pppp

    case .ppp:
        .ppp

    case .pp,
         .sfpp:
        .pp

    case .fp,
         .p,
         .sfp,
         .sfzp:
        .p

    case .mp:
        .mp

    case .mf:
        .mf

    case .f,
         .pf:
        .f

    case .ff,
         .sffz:
        .ff

    case .fff:
        .fff

    case .ffff,
         .fffff,
         .ffffff:
        .ffff

    case .n:
        Dynamic(numberValue: 0)

    case .fz,
         .otherDynamics,
         .rf,
         .rfz,
         .sf,
         .sfz:
        nil
    }
}

// A note's own `dynamics` attribute is a percentage of the default forte
// velocity (90, per the MIDI 1.0 convention the MusicXML spec cites), so it
// converts to an actual velocity the same way — `percent / 100 * 90` — and
// on to `Dynamic` exactly as `convertToDynamic(_ keyVelocity:)` in
// `MIDIFunctions.swift` does, keeping the two importers' scales consistent.
internal func convertToDynamic(_ note: MXLNote) -> Dynamic? {
    _convertToDynamic(percent: note.dynamics)
}

// A `<sound>`'s own `dynamics` attribute converts exactly like a note's own
// `dynamics` — see `convertToDynamic(_ note:)`. `<sound>` can appear nested
// in a `<direction>` alongside that direction's own notated `<dynamics>`
// mark, where it takes priority: a `<sound>` is itself a MIDI-style
// playback hint, the same kind of source a note's own velocity is, rather
// than the visual-only marking a `<direction>`'s `<dynamics>` element is.
internal func convertToDynamic(_ sound: MXLSound) -> Dynamic? {
    _convertToDynamic(percent: sound.dynamics)
}

// A part's own first `<score-instrument>` name wins — the same "first/
// default instrument only" reading `determinePartName` already gives a
// multi-instrument part elsewhere — falling back to its first `<midi-
// instrument>` program number (via `<score-part>`'s own `group2`, a MIDI
// device/instrument assignment made directly on the part rather than nested
// in a `<score-instrument>`) when no name was written. `nil` when neither is
// present, leaving the part's `InstrumentMap` empty.
internal func convertToInstrument(_ scorePart: MusicXML.ScorePart) -> Instrument? {
    if let name = scorePart.instrument.first?.name.nilIfEmpty {
        return Instrument(stringValue: name)
    }

    guard let program = scorePart.group2.lazy.compactMap(\.midiInstrument?.midiProgram).first
    else { return nil }

    return Instrument(stringValue: generalMIDIInstrumentName(program: Int(program.uintValue) - 1))
}

// A quarter-note-based `BeatDuration` expressed in the work's own
// `<divisions>` resolution, rounded to the nearest whole division and
// promoted up to `1` division if it would otherwise round to `0`, so a
// vanishingly short segment never disappears entirely.
internal func convertToMusicXMLDivisions(_ duration: BeatDuration,
                                         _ divisions: Int) -> MXLPositiveDivisions? {
    let raw = (duration.numberValue * Number(divisions)).doubleValue
    let rounded = max(1, Int(raw.rounded()))

    return MXLPositiveDivisions(intValue: rounded)
}

// The reverse of `convertToDynamic(_ item:)`: only the ten exact levels
// `Dynamic` names have a single unambiguous `<dynamics>` mark, so anything
// else (an arbitrary interpolated ramp midpoint, for instance) converts to
// `nil` rather than guessing at the nearest named mark.
internal func convertToMusicXMLDynamics(_ dynamic: Dynamic) -> MXLDynamics.Item? {
    switch dynamic {
    case .pppp:
        .pppp

    case .ppp:
        .ppp

    case .pp:
        .pp

    case .p:
        .p

    case .mp:
        .mp

    case .mf:
        .mf

    case .f:
        .f

    case .ff:
        .ff

    case .fff:
        .fff

    case .ffff:
        .ffff

    default:
        nil
    }
}

// The reverse of `convertToStandardPitch(_:)`. Throws
// `MusicXML.Error.unrecognizedPitchOctave` for `Pitch.Octave`’s one value
// (`-1`) that has no `MXLOctave` equivalent (`0...9`) — the same
// export-direction reuse of an import-direction error case the Guido and ABC
// exporters already establish for their own out-of-range octaves.
internal func convertToMusicXMLPitch(_ pitch: Pitch) throws(MusicXML.Error) -> MusicXML.Pitch {
    try MusicXML.Pitch(step: _convertToMusicXMLStep(pitch.pitchClass.letter),
                       alter: _convertToMusicXMLAlter(pitch.pitchClass.accidental),
                       octave: _convertToMusicXMLOctave(pitch.octave))
}

// A `<sound>`’s own `pan`, the same deprecated-but-simpler attribute
// `convertToPan(_:)` falls back to reading — writing through the newer
// midi-instrument `<pan>` element instead would require a `<score-instrument>`
// identity this call site has no reason to mint just for a pan change.
internal func convertToMusicXMLSound(pan: Pan) -> MXLSound {
    MXLSound(pan: pan.numberValue.doubleValue * 90)
}

// `<sound tempo>` is already expressed directly in quarter notes per minute,
// the same unit `Tempo` uses, so no scaling is needed beyond the type
// conversion — the reverse of `convertToTempo(_ sound:)`.
internal func convertToMusicXMLSound(tempo: Tempo) -> MXLSound {
    MXLSound(tempo: tempo.doubleValue)
}

// A `<sound>`'s midi-instrument `<pan>` takes priority over the sound
// element's own `pan` attribute, which the MusicXML spec deprecated in favor
// of the midi-instrument element. Degrees run -180...180, with -90 hard left
// and 90 hard right (180/-180 sit directly behind the listener); `Pan` only
// models the stereo axis, so anything past ±90° clamps to the nearest hard
// side rather than wrapping.
internal func convertToPan(_ sound: MXLSound) -> Pan? {
    guard let degrees = sound.group.lazy.compactMap(\.midiInstrument?.pan).first ?? sound.pan
    else { return nil }

    return Pan(numberValue: Number(min(1, max(-1, degrees / 90))))
}

internal func convertToStandardPitch(_ pitch: MusicXML.Pitch) throws(MusicXML.Error) -> Pitch {
    try Pitch(pitchClass: _convertToStandardPitchClass(pitch.step,
                                                       pitch.alter),
              octave: _convertToStandardPitchOctave(pitch.octave))
}

// A visual metronome mark (`♩ = 120`, or a dotted/other beat unit) converts
// to quarter notes per minute the same way `<sound tempo>` is already
// expressed, by scaling the stated per-minute rate by how many quarter
// notes its beat unit is worth. Only the ordinary "note = number" form
// (`.beatUnit`/`.perMinute`) names an actual tempo; the metric-modulation
// forms (`.metronomeArrows`, `.beatUnit`/`.beatUnit` note-equivalence, or a
// non-numeric `per-minute` text like "ca. 120") describe a *relationship*
// rather than a rate and are left unrecognized.
internal func convertToTempo(_ metronome: MXLMetronome) -> Tempo? {
    guard case let .beatUnit(beatUnit, _, .perMinute(perMinute)) = metronome.content,
          let perMinuteValue = Double(perMinute.value),
          perMinuteValue > 0
    else { return nil }

    let quarterBPM = perMinuteValue * _quarterNoteFactor(beatUnit)

    guard let uintValue = UInt(exactly: quarterBPM.rounded())
    else { return nil }

    return Tempo(uintValue: uintValue)
}

// `<sound tempo>` is already expressed directly in quarter notes per minute
// per the MusicXML spec, so no unit conversion is needed — just rounding to
// the nearest representable `Tempo`. A tempo of `0` is the MusicXML
// convention for "prompt the user at the time of compiling a sound file" and
// is never inserted.
internal func convertToTempo(_ sound: MXLSound) -> Tempo? {
    guard let tempo = sound.tempo,
          tempo > 0
    else { return nil }

    guard let uintValue = UInt(exactly: tempo.rounded())
    else { return nil }

    return Tempo(uintValue: uintValue)
}

// Some notation software (MuseScore, at least) writes the literal string
// "MusicXML Part" into `<part-name>` — marked non-printing — for a
// single-instrument score whose user never set a real part name; the
// element only exists because the schema requires one, not to identify the
// part. That placeholder, or an outright empty name, is worth trading for
// the first `<score-instrument>`'s own `instrument-name` when one is
// present — a real, human-meaningful label the placeholder never is.
//
// A part whose own `<part-name>` is just digits and whitespace ("1 2",
// "3 4", "3") is a different case entirely, not covered by either fallback
// above: standard engraving practice for a numbered staff inside a
// braced/bracketed instrument-family group, which is labeled once at the
// group and left for each staff underneath to carry only its number (see
// `ActorPreludeSample.mxl`'s horns and trombones). `<score-instrument>`
// doesn't help here either — its `instrument-name` is typically a sample-
// library patch label ("Hn. (V2k)") no more specific than the bare
// numerals — so `groupName`, the caller-supplied name of that enclosing
// group (see `MusicXML.Importer._groupNames(_:)`), is combined with the
// numerals instead: "Horns in F (1, 2)".
internal func determinePartName(_ scorePart: MusicXML.ScorePart,
                                groupName: String?) -> String {
    let name = scorePart.name.value

    if let groupName, !name.isEmpty, !name.contains(where: \.isLetter) {
        let numerals = name.split(whereSeparator: \.isWhitespace).joined(separator: ", ")

        return "\(groupName) (\(numerals))"
    }

    guard name.isEmpty || name == "MusicXML Part"
    else { return name }

    return scorePart.instrument.first?.name.nilIfEmpty ?? name
}

internal func determineWorkName(_ score: MusicXML.Score) -> String {
    let movementNumber = score.movementNumber?.nilIfEmpty
    let movementTitle = score.movementTitle?.nilIfEmpty
    let workNumber = score.work?.number?.nilIfEmpty
    let workTitle = score.work?.title?.nilIfEmpty

    let combinedWorkTitle: String? = if let workTitle,
                                        let workNumber {
        workTitle + ", " + workNumber
    } else if let workTitle {
        workTitle
    } else if let workNumber {
        workNumber
    } else {
        nil
    }

    let combinedMovementTitle: String? = if let movementTitle,
                                            let movementNumber {
        movementTitle + ", " + movementNumber
    } else if let movementTitle {
        movementTitle
    } else if let movementNumber {
        movementNumber
    } else {
        nil
    }

    if let combinedWorkTitle,
       let combinedMovementTitle {
        return combinedWorkTitle + ": " + combinedMovementTitle
    }

    return combinedWorkTitle ?? combinedMovementTitle ?? ""
}

// The first `<metronome>` a `<direction>` carries, if any — a direction
// realistically carries at most one metronome mark.
internal func extractMetronome(_ direction: MXLDirection) -> MXLMetronome? {
    for kind in direction.kind {
        if case let .metronome(metronome) = kind.content {
            return metronome
        }
    }

    return nil
}

// The first `<wedge>` a `<direction>` carries, if any — a direction
// realistically carries at most one crescendo/diminuendo hairpin marking.
internal func extractWedge(_ direction: MXLDirection) -> MXLWedge? {
    for kind in direction.kind {
        if case let .wedge(wedge) = kind.content {
            return wedge
        }
    }

    return nil
}

// MARK: Private Functions

// Shared by `convertToDynamic(_ note:)` and `convertToDynamic(_ sound:)`:
// a percentage of the default forte velocity (90, per the MIDI 1.0
// convention the MusicXML spec cites) converts to an actual velocity —
// `percent / 100 * 90` — and on to `Dynamic` exactly as
// `convertToDynamic(_ keyVelocity:)` in `MIDIFunctions.swift` does, keeping
// every importer's scale consistent.
private func _convertToDynamic(percent: MXLNonNegativeDecimal?) -> Dynamic? {
    guard let percent,
          percent > 0
    else { return nil }

    let velocity = percent / 100 * 90

    return Dynamic(numberValue: Number(min(1, velocity / 127)))
}

// The reverse of `_convertToStandardPitchClass(_:_:)`'s accidental leg.
// `.natural` converts to `nil` rather than an explicit `0` — the common,
// unadorned MusicXML spelling — while every other accidental converts to its
// signed semitone count.
private func _convertToMusicXMLAlter(_ accidental: Pitch.Accidental) -> MusicXML.Semitones? {
    switch accidental {
    case .doubleFlat:
        -2

    case .doubleSharp:
        2

    case .flat:
        -1

    case .natural:
        nil

    case .sharp:
        1
    }
}

// The reverse of `_convertToStandardPitchOctave(_:)`. `Pitch.Octave`'s range
// (`-1...9`) has exactly one value `MXLOctave` (`0...9`) cannot represent.
private func _convertToMusicXMLOctave(_ octave: Pitch.Octave) throws(MusicXML.Error) -> MusicXML.Octave {
    guard octave.intValue >= 0,
          let mpOctave = MusicXML.Octave(uintValue: UInt(octave.intValue))
    else { throw MusicXML.Error.unrecognizedPitchOctave(octave.intValue) }

    return mpOctave
}

// The reverse of `_convertToStandardPitchClass(_:_:)`'s step leg.
private func _convertToMusicXMLStep(_ letter: Pitch.Letter) -> MusicXML.Step {
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

// Maps MusicXML's step + chromatic-alteration representation to our own
// letter + accidental model. `mpAlter` is `nil` or `0` for a natural pitch;
// a fractional (microtonal) value has no representation in `Pitch.Accidental`
// and is rejected.
private func _convertToStandardPitchClass(_ mpStep: MusicXML.Step,
                                          _ mpAlter: MusicXML.Semitones?) throws(MusicXML.Error) -> PitchClass {
    let letter: Pitch.Letter = switch mpStep {
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

    let accidental: Pitch.Accidental = switch mpAlter ?? 0 {
    case -2:
        .doubleFlat

    case -1:
        .flat

    case 0:
        .natural

    case 1:
        .sharp

    case 2:
        .doubleSharp

    default:
        throw MusicXML.Error.unrecognizedPitchAccidental(mpAlter ?? 0)
    }

    return PitchClass(letter: letter,
                      accidental: accidental)
}

private func _convertToStandardPitchOctave(_ mpOctave: MusicXML.Octave) throws(MusicXML.Error) -> Pitch.Octave {
    guard let octave = Pitch.Octave(intValue: Int(mpOctave.uintValue))
    else { throw MusicXML.Error.unrecognizedPitchOctave(Int(mpOctave.uintValue)) }

    return octave
}

// How many quarter notes a metronome mark's beat unit is worth — the same
// note-value scale `convertToBeatDuration`/`convertToBeatTime` read off a
// note's own `<type>`, extended with each augmentation dot's usual 1.5×
// (`2 - 1/2^dots`).
private func _quarterNoteFactor(_ beatUnit: MXLBeatUnit) -> Double {
    let base: Double = switch beatUnit.beatUnit {
    case .maxima:
        32

    case .long:
        16

    case .breve:
        8

    case .whole:
        4

    case .half:
        2

    case .quarter:
        1

    case .eighth:
        0.5

    case .n16th:
        0.25

    case .n32nd:
        0.125

    case .n64th:
        0.0625

    case .n128th:
        0.03125

    case .n256th:
        0.015625

    case .n512th:
        0.0078125

    case .n1024th:
        0.00390625
    }

    let dotFactor = 2 - 1 / Double(1 << beatUnit.dot)

    return base * dotFactor
}
