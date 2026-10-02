// © 2025–2026 John Gary Pusey (see LICENSE.md)

internal import IvorModel
internal import IvorSMPTE
internal import IvorTiming
internal import IvorTuning

private import Foundation
private import IvorMIDI
private import IvorSMF
private import XestiNumbers
private import XestiTools

// MARK: Internal Functions

internal func convertToDynamic(_ keyVelocity: MIDI.KeyVelocity) -> Dynamic? {
    Dynamic(numberValue: Number(Double(keyVelocity.uintValue) / 127.0))
}

internal func convertToInstrument(_ program: MIDI.ProgramNumber) -> Instrument {
    Instrument(stringValue: generalMIDIInstrumentName(program: Int(program.uintValue))) ?? .vanilla
}

internal func convertToMIDIEventTime(_ beatTime: BeatTime,
                                     _ tickRate: MIDI.TickRate) -> MIDI.EventTime? {
    MIDI.EventTime(uintValue: UInt((beatTime.doubleValue * Double(tickRate.uintValue)).rounded()))
}

internal func convertToMIDIKeyVelocity(_ dynamic: Dynamic) -> MIDI.KeyVelocity? {
    MIDI.KeyVelocity(uintValue: max(1, UInt((dynamic.doubleValue * 127.0).rounded())))
}

internal func convertToMIDINoteNumber(_ pitch: NoteNumber) -> MIDI.NoteNumber? {
    MIDI.NoteNumber(uintValue: pitch.uintValue)
}

internal func convertToMIDIPanValue(_ pan: Pan) -> MIDI.PanValue? {
    MIDI.PanValue(uintValue: UInt((((pan.stereo.doubleValue + 1.0) / 2.0) * 127.0).rounded()))
}

internal func convertToMIDIProgramNumber(_ instrument: Instrument) -> MIDI.ProgramNumber? {
    guard let program = generalMIDIProgramNumber(name: instrument.stringValue)
    else { return nil }

    return MIDI.ProgramNumber(uintValue: UInt(program))
}

internal func convertToMIDITempo(_ tempo: Tempo) -> MIDI.Tempo? {
    MIDI.Tempo(uintValue: 60_000_000 / tempo.uintValue)
}

// SMF text is one byte per character, which IvorSMF reads and writes as
// Latin-1, and `SMFValidator` rejects any text that can't be encoded that
// way. So a character outside Latin-1 — a curly quote, a dash, a ℗, a
// non-Latin script — is transliterated to Latin-1 instead (`’` → `'`,
// `℗` → `(P)`, `日本` → `ri ben`), and written as `?` only if even that
// fails, rather than failing the whole export.
internal func convertToMIDIText(_ text: String) -> MIDI.Text? {
    guard !_isLatin1(text)
    else { return MIDI.Text(stringValue: text) }

    var result = ""

    for character in text {
        let string = String(character)

        if _isLatin1(string) {
            result += string
        } else if let transliterated = string.applyingTransform(StringTransform("Any-Latin; Latin-ASCII"), reverse: false),
                  _isLatin1(transliterated) {
            result += transliterated
        } else {
            result += "?"
        }
    }

    return MIDI.Text(stringValue: result)
}

internal func convertToNoteNumber(_ noteNumber: MIDI.NoteNumber) -> NoteNumber {
    NoteNumber(noteNumber.uintValue)
}

internal func convertToPan(_ panValue: MIDI.PanValue) -> Pan? {
    Pan(stereo: Number(((Double(panValue.uintValue) / 127.0) * 2.0) - 1.0))
}

internal func convertToTempo(_ tempo: MIDI.Tempo,
                             _ factor: MIDI.BeatMap.Factor) -> Tempo {
    Tempo(round(factor * Number(numerator: 60_000_000,
                                denominator: tempo.uintValue)).exact.uintValue)
}

// Scans one track's own events for its `sequenceTrackName` meta event
// text, or `nil` if it never declared one. `determineWorkName` reads
// track 0's name as the work's name; `MIDI.Importer` reads every other
// track's own name as its `Part`'s name.
internal func determineTrackName(_ track: MIDI.Track) -> String? {
    for event in track.events {
        guard case let .meta(_, .sequenceTrackName(name)) = event
        else { continue }

        return normalizeName(name.stringValue).nilIfEmpty
    }

    return nil
}

internal func determineWorkName(_ sequence: MIDI.Sequence) -> String {
    guard let track0 = sequence.tracks.first
    else { return "" }

    return determineTrackName(track0) ?? ""
}

// The timecode division `MIDI.Importer` recorded on a work it read from a
// file with one (see `MIDI.Importer._makeStartElements`), so that
// `MIDI.Exporter` can write it back: in a `midiTimeCode` extra on the tempo
// map entry at beat zero of a beat-time work, or on each part's instrument
// map entry at time zero of a wall-time work. The first one SMF can encode
// wins; a frame rate it can't, or a number of ticks per frame outside
// 1–255, is skipped.
internal func determineTimeCode(_ content: Work.Content) -> MIDI.TimeCode? {
    switch content {
    case let .absoluteBeat(_, tempoMap),
         let .keyboardBeat(_, tempoMap),
         let .standardBeat(_, tempoMap):
        _determineTimeCode(_startExtras(tempoMap))

    case let .absoluteWall(parts):
        _determineTimeCode(_startExtras(parts))

    case let .keyboardWall(parts):
        _determineTimeCode(_startExtras(parts))

    case let .standardWall(parts):
        _determineTimeCode(_startExtras(parts))
    }
}

// The start time a file with this division implies when it has no SMPTE
// Offset: 00:00:00:00 at a timecode division's frame rate, or the default
// under a metrical one. `MIDI.Importer` gives such a file's work this start
// time, so `MIDI.Exporter` can leave out an offset that would only restate
// it.
internal func impliedSMPTEStartTime(_ division: MIDI.Division) -> SMPTETime {
    guard case let .timeCode(timeCode) = division,
          let startTime = SMPTETime(frameRate: timeCode.frameRate,
                                    frameCount: 0,
                                    subframe: 0)
    else { return Work.defaultSMPTEStartTime }

    return startTime
}

// The RP-026 song information tags in one Lyric meta event's text —
// `{#Title=…}`, `{#Composer=…}`, `{#Lyrics=…}`, `{#Artist=…}` — as name and
// value pairs, in order. RP-026 puts them at the start of the lyrics,
// ended by a bare `{#}`, which (like any tag with no `=`) yields nothing.
internal func parseSongInformation(_ text: String) -> [(name: String, value: String)] {
    var results: [(name: String, value: String)] = []
    var rest = text[...]

    while let open = rest.range(of: "{#") {
        guard let close = rest[open.upperBound...].firstIndex(of: "}")
        else { break }

        let tag = rest[open.upperBound..<close]

        if let equals = tag.firstIndex(of: "=") {
            results.append((String(tag[..<equals]), String(tag[tag.index(after: equals)...])))
        }

        rest = rest[rest.index(after: close)...]
    }

    return results
}

// MARK: Private Functions

private func _determineTimeCode(_ startExtras: [Extras]) -> MIDI.TimeCode? {
    for extras in startExtras {
        guard let values = extras.elements.first(where: { $0.name == Extra.midiTimeCode.name })?.values,
              values.count == 2,
              case let .string(frameRateString) = values[0],
              case let .int(ticksPerFrameValue) = values[1],
              let frameRate = SMPTEFrameRate(string: frameRateString),
              let ticksPerFrame = UInt(exactly: ticksPerFrameValue),
              let timeCode = MIDI.TimeCode(frameRate: frameRate,
                                           ticksPerFrame: ticksPerFrame)
        else { continue }

        return timeCode
    }

    return nil
}

private func _isLatin1(_ text: String) -> Bool {
    text.unicodeScalars.allSatisfy { $0.value <= 0xff }
}

// The extras of every instrument map entry at time zero, in part order.
private func _startExtras(_ parts: [Part<WallTime, some PitchProtocol>]) -> [Extras] {
    parts.flatMap { part in
        part.instrumentMap.compactMap { $0.time == .zero ? $0.extras : nil }
    }
}

// The extras of every tempo map entry at beat zero.
private func _startExtras(_ tempoMap: TempoMap) -> [Extras] {
    tempoMap.compactMap { $0.beatTime == .zero ? $0.extras : nil }
}
