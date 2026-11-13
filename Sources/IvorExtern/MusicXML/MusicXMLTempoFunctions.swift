// © 2026 John Gary Pusey (see LICENSE.md)

internal import IvorMXL
internal import IvorTiming

private import Foundation
private import XestiNumbers

// A tempo is written as a visible `<metronome>` mark in its own unit (when
// that's a plain or dotted note value) and a `<sound tempo>` playback hint,
// which MusicXML always states in quarter notes per minute. On import, the
// speed comes from the sound and the unit from the metronome mark.

// MARK: Internal Functions

// A tempo's visible `<metronome>` mark, in its own unit when that's a plain
// or dotted note value (`♩. = 90`), and otherwise restated in quarter
// notes. The rate is written rounded to a whole number (see
// `roundedTempoRate(_:)`), as the app shows it; the exact speed is in the
// `<sound tempo>` written alongside (see `convertToMusicXMLSound(tempo:)`).
internal func convertToMusicXMLMetronome(_ tempo: Tempo) -> MXLMetronome? {
    let shown = plainOrDottedNoteValue(tempo.unit) == nil ? tempo.restated(in: .quarter) : tempo

    guard let (base, dots) = plainOrDottedNoteValue(shown.unit),
          let kind = _noteKindValue(base)
    else { return nil }

    return MXLMetronome(content: .beatUnit(MXLBeatUnit(beatUnit: kind,
                                                       dot: Int(dots)),
                                           tied: [],
                                           content: .perMinute(MXLPerMinute(value: String(roundedTempoRate(shown))))))
}

// `<sound tempo>` is in quarter notes per minute, whatever unit the tempo is
// stated in — the reverse of `convertToTempo(_ sound:)`.
internal func convertToMusicXMLSound(tempo: Tempo) -> MXLSound {
    MXLSound(tempo: tempo.doubleValue * 4)
}

// A visual metronome mark (`♩. = 80`) as a tempo in its own unit: the
// beat unit, with its dots, and the exact per-minute rate. Only the
// ordinary "note = number" form (`.beatUnit`/`.perMinute`) names an actual
// tempo; the metric-modulation forms (`.metronomeArrows`,
// `.beatUnit`/`.beatUnit` note-equivalence, or a non-numeric `per-minute`
// text like "ca. 120") describe a *relationship* rather than a rate and are
// left unrecognized.
internal func convertToTempo(_ metronome: MXLMetronome) -> Tempo? {
    guard case let .beatUnit(beatUnit, _, .perMinute(perMinute)) = metronome.content,
          let rate = Tempo(plain: perMinute.value.trimmingCharacters(in: .whitespaces))?.rate
    else { return nil }

    return Tempo(rate: rate,
                 unit: _wholeNoteValue(beatUnit))
}

// `<sound tempo>` is in quarter notes per minute per the MusicXML spec, so a
// sound alone gives a quarter-note tempo, its rate kept exactly as written
// (`66.5` stays 133/2). A tempo of `0` is the MusicXML convention for
// "prompt the user at the time of compiling a sound file" and is never
// inserted.
internal func convertToTempo(_ sound: MXLSound) -> Tempo? {
    guard let tempo = sound.tempo,
          tempo > 0,
          tempo.isFinite
    else { return nil }

    return Tempo(plain: "\(tempo)")
}

// A `<direction>`'s tempo: the speed comes from its `<sound tempo>` if it has
// one, stated in its `<metronome>`'s unit if it has one of those too (so
// `♩. = 80` with `<sound tempo="120"/>` is ♩. = 80). Without a sound, the
// metronome mark alone gives the tempo.
internal func convertToTempo(sound: MXLSound?,
                             metronome: MXLMetronome?) -> Tempo? {
    let metronomeTempo = metronome.flatMap { convertToTempo($0) }

    guard let soundTempo = sound.flatMap({ convertToTempo($0) })
    else { return metronomeTempo }

    guard let metronomeTempo
    else { return soundTempo }

    return soundTempo.restated(in: metronomeTempo.unit)
}

// A tempo's `<direction>`: its `<metronome>` mark (see
// `convertToMusicXMLMetronome(_:)`), with the exact speed in `<sound
// tempo>`. A tempo with no metronome mark gets an empty `<words>` instead,
// the conventional, invisible placeholder for a direction with nothing of its
// own to display.
internal func makeMusicXMLTempoDirection(_ tempo: Tempo) -> MXLDirection {
    let content: MXLDirection.Kind.Content = if let metronome = convertToMusicXMLMetronome(tempo) {
        .metronome(metronome)
    } else {
        .words(MXLFormattedTextID(value: ""))
    }

    return MXLDirection(kind: [MXLDirection.Kind(content: content)],
                        sound: convertToMusicXMLSound(tempo: tempo))
}

// MARK: Private Functions

// The note value of a `<type>` or `<beat-unit>`, in whole notes.
private func _noteKindNumber(_ kind: MXLNoteKindValue) -> Number {
    switch kind {
    case .breve:
        2

    case .eighth:
        Number(numerator: 1,
               denominator: 8)

    case .half:
        Number(numerator: 1,
               denominator: 2)

    case .long:
        4

    case .maxima:
        8

    case .n1024th:
        Number(numerator: 1,
               denominator: 1_024)

    case .n128th:
        Number(numerator: 1,
               denominator: 128)

    case .n16th:
        Number(numerator: 1,
               denominator: 16)

    case .n256th:
        Number(numerator: 1,
               denominator: 256)

    case .n32nd:
        Number(numerator: 1,
               denominator: 32)

    case .n512th:
        Number(numerator: 1,
               denominator: 512)

    case .n64th:
        Number(numerator: 1,
               denominator: 64)

    case .quarter:
        Number(numerator: 1,
               denominator: 4)

    case .whole:
        1
    }
}

// The reverse of `_noteKindNumber(_:)`, or `nil` for a value that names no
// note kind.
private func _noteKindValue(_ value: Number) -> MXLNoteKindValue? {
    let kinds: [MXLNoteKindValue] = [.maxima,
                                     .long,
                                     .breve,
                                     .whole,
                                     .half,
                                     .quarter,
                                     .eighth,
                                     .n16th,
                                     .n32nd,
                                     .n64th,
                                     .n128th,
                                     .n256th,
                                     .n512th,
                                     .n1024th]

    return kinds.first { _noteKindNumber($0) == value }
}

// A metronome mark's beat unit in whole notes: its note value, extended by
// each augmentation dot (`2 - 1/2^dots` times the value).
private func _wholeNoteValue(_ beatUnit: MXLBeatUnit) -> BeatDuration {
    let dots = max(0, beatUnit.dot)
    let dotFactor = 2 - Number(numerator: 1, denominator: 1 << dots)

    return BeatDuration(_noteKindNumber(beatUnit.beatUnit) * dotFactor)
}
