// © 2025–2026 John Gary Pusey (see LICENSE.md)

internal import IvorModel
internal import IvorSMPTE
internal import IvorTiming
internal import IvorTuning
internal import XestiTools

private import Foundation
private import IvorGeneralMIDI
private import IvorMIDI
private import IvorSMF
private import XestiNumbers

// MARK: Internal Functions

internal func convertToDynamic(_ keyVelocity: MIDI.KeyVelocity) -> Dynamic? {
    Dynamic(numberValue: Number(Double(keyVelocity.uintValue) / 127.0))
}

internal func convertToInstrument(_ program: MIDI.Program) -> Instrument {
    Instrument(stringValue: GM1Instrument(program: program).name) ?? .vanilla
}

// A time signature's meter: its numerator over two to the power of its
// denominator. Clocks per click and 32nds per quarter never affect it (see
// `convertToMIDITimeSignatureExtras(_:)`).
internal func convertToMeter(_ timeSignature: MIDI.TimeSignature) -> Meter? {
    guard timeSignature.denominator < UInt.bitWidth - 1
    else { return nil }

    return Meter(numerators: [timeSignature.numerator],
                 denominator: 1 << timeSignature.denominator)
}

internal func convertToMIDIEventTime(_ beatTime: BeatTime,
                                     _ tickRate: MIDI.TickRate) -> MIDI.EventTime? {
    MIDI.EventTime(uintValue: UInt((beatTime.doubleValue * 4 * Double(tickRate.uintValue)).rounded()))
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

internal func convertToMIDIProgram(_ instrument: Instrument) -> MIDI.Program? {
    instrument.generalMIDIInstrument?.program
}

// MIDI states every tempo in microseconds per quarter note: 60,000,000
// divided by the quarter-note rate, which is 15,000,000 divided by the speed
// in whole notes per minute. It's rounded to the nearest microsecond only
// here, on export.
internal func convertToMIDITempo(_ tempo: Tempo) -> MIDI.Tempo? {
    let microseconds = round(Number(15_000_000) / tempo.numberValue).exact

    guard !microseconds.isNegative
    else { return nil }

    return MIDI.Tempo(uintValue: microseconds.uintValue)
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

// The time signature written for a meter entry, or `nil` if there's none: a
// time signature can only state one numerator over a power of two. A meter
// over a power of two is written as the sum of its numerators over its
// denominator (2+2+3/8 as 7/8). Any other metered meter whose bar length is a
// whole number of some power-of-two note value is written as that (6/12 as
// 2/4, by its quarter-note pulse; 3/6 as 2/4). A free meter, or one like 4/3
// or 7/12, has none. The entry's `midiTimeSignature` extra supplies clocks
// per click and 32nds per quarter; without it, 24 and 8.
internal func convertToMIDITimeSignature(_ meter: Meter,
                                         _ extras: Extras?) -> MIDI.TimeSignature? {
    guard let (numerator, exponent) = _powerOfTwoMeter(meter)
    else { return nil }

    let values = extras?.elements.first { $0.name == Extra.midiTimeSignature.name }?.values ?? []
    var clockRate: UInt = 24
    var beatRate: UInt = 8

    if values.count == 2,
       case let .int(clocks) = values[0],
       case let .int(notes) = values[1],
       let clocks = UInt(exactly: clocks),
       let notes = UInt(exactly: notes) {
        clockRate = clocks
        beatRate = notes
    }

    return MIDI.TimeSignature(numerator: numerator,
                              denominator: exponent,
                              clockRate: clockRate,
                              beatRate: beatRate)
}

// The `midiTimeSignature` extra for an imported time signature: its clocks
// per click and 32nds per quarter, or `nil` when they're the defaults (24
// and 8) that the exporter writes anyway.
internal func convertToMIDITimeSignatureExtras(_ timeSignature: MIDI.TimeSignature) -> Extras? {
    guard timeSignature.clockRate != 24 || timeSignature.beatRate != 8
    else { return nil }

    return Extras(elements: [Extra(name: Extra.midiTimeSignature.name,
                                   values: [.int(Int(timeSignature.clockRate)),
                                            .int(Int(timeSignature.beatRate))])])
}

internal func convertToNoteNumber(_ noteNumber: MIDI.NoteNumber) -> NoteNumber {
    NoteNumber(noteNumber.uintValue)
}

internal func convertToPan(_ panValue: MIDI.PanValue) -> Pan? {
    Pan(stereo: Number(((Double(panValue.uintValue) / 127.0) * 2.0) - 1.0))
}

// A MIDI tempo, in microseconds per quarter note, as an exact quarter-note
// rate: 60,000,000 divided by the microseconds. Clocks per click never
// affects it. A tempo of zero microseconds, which no valid file holds, gives
// the default tempo.
internal func convertToTempo(_ tempo: MIDI.Tempo) -> Tempo {
    guard tempo.uintValue > 0
    else { return .default }

    return Tempo(rate: Number(numerator: 60_000_000,
                              denominator: tempo.uintValue),
                 unit: .quarter) ?? .default
}

// The timecode division `MIDI.Importer` recorded on a work it read from a
// file with one (see `MIDI.Importer._makeExtras`), so that `MIDI.Exporter`
// can write it back: in a `midiTimeCode` extra on the work itself, whatever
// its time basis. A frame rate SMF can't encode, or a number of ticks per
// frame outside 1–255, counts as none.
internal func determineTimeCode(_ work: Work) -> MIDI.TimeCode? {
    guard let values = work.extras?.elements.first(where: { $0.name == Extra.midiTimeCode.name })?.values,
          values.count == 2,
          case let .string(frameRateString) = values[0],
          case let .int(ticksPerFrameValue) = values[1],
          let frameRate = SMPTEFrameRate(string: frameRateString),
          let ticksPerFrame = UInt(exactly: ticksPerFrameValue)
    else { return nil }

    return MIDI.TimeCode(frameRate: frameRate,
                         ticksPerFrame: ticksPerFrame)
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

// The exact key velocity an importer kept on a note (its `attackVelocity`
// extra), if any. A note with one sounds at that velocity rather than one
// converted from the dynamic level at its attack.
internal func exactKeyVelocity(_ extras: Extras?) -> MIDI.KeyVelocity? {
    intValue(extras, .attackVelocity).flatMap { MIDI.KeyVelocity(uintValue: UInt(clamping: $0)) }
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

// The text of the marker meta event that states a meter entry's meter
// exactly — `Ivor meter <plain>`, such as `Ivor meter 4/3` — or `nil` if the
// entry's time signature already says it all (see
// `convertToMIDITimeSignature(_:_:)`). A free meter, a grouped meter, and a
// meter with no time signature of its own all need one; a simple meter
// written as a stand-in of the same bar length (6/12 as 2/4) doesn't.
// `MIDI.Importer` reads it back with `parseMeterMarker(_:)`.
internal func makeMeterMarker(_ meter: Meter) -> MIDI.Text? {
    guard meter.numerators.count != 1 || _powerOfTwoMeter(meter) == nil
    else { return nil }

    return MIDI.Text(stringValue: meterMarkerPrefix + meter.plain)
}

// The meter a marker meta event states, if it's one `makeMeterMarker(_:)`
// wrote.
internal func parseMeterMarker(_ text: String) -> Meter? {
    guard text.hasPrefix(meterMarkerPrefix)
    else { return nil }

    return Meter(plain: String(text.dropFirst(meterMarkerPrefix.count)).trimmingCharacters(in: .whitespaces))
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

// MARK: Private Constants

private let meterMarkerPrefix = "Ivor meter "

// MARK: Private Functions

private func _isLatin1(_ text: String) -> Bool {
    text.unicodeScalars.allSatisfy { $0.value <= 0xff }
}

// The numerator and power-of-two exponent a time signature writes for a
// meter (see `convertToMIDITimeSignature(_:_:)`), or `nil` if there's none.
private func _powerOfTwoMeter(_ meter: Meter) -> (numerator: UInt, exponent: UInt)? {
    guard let denominator = meter.denominator,
          let barLength = meter.barLength
    else { return nil }

    if denominator.nonzeroBitCount == 1 {
        let numerator = meter.numerators.reduce(0, +)

        guard numerator <= 255
        else { return nil }

        return (numerator, UInt(denominator.trailingZeroBitCount))
    }

    var exponents: [UInt] = []

    if let pulse = meter.evenPulse,
       pulse.numberValue.numerator == 1,
       pulse.numberValue.denominator.uintValue.nonzeroBitCount == 1 {
        exponents.append(UInt(pulse.numberValue.denominator.uintValue.trailingZeroBitCount))
    }

    exponents += Array(2...8)

    for exponent in exponents {
        let numerator = barLength.numberValue * Number(1 << exponent)

        if numerator.denominator == 1,
           (1...255).contains(numerator.numerator.uintValue) {
            return (numerator.numerator.uintValue, exponent)
        }
    }

    return nil
}
