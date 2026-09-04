// © 2025–2026 John Gary Pusey (see LICENSE.md)

import Foundation
import IvorABC
@testable import IvorExtern
import IvorGuido
import IvorModel
import IvorMusicXML
import IvorTiming
import IvorTuning
import Testing

// Parses `text` as a minimal ABC tune body (`X:1`/`K:C` header prepended)
// and returns the flattened symbol stream from its first body line. Shared
// by any test that needs realistic `ABCSymbol` values without hand-building
// the AST.
internal func abcSymbols(from text: String,
                         sourceLocation: SourceLocation = #_sourceLocation) throws -> [ABCSymbol] {
    let (tunebook, _) = try ABC.BaseParser().parse(Data("X:1\nK:C\n\(text)\n".utf8))
    let tune = try #require(tunebook.tunes.first,
                            sourceLocation: sourceLocation)

    return tune.body.flatMap { entry -> [ABCSymbol] in
        guard case let .symbols(symbols) = entry
        else { return [] }

        return symbols
    }
}

// Parses `musicXML` as an uncompressed MusicXML document and returns its
// score-partwise content. Shared by any test that needs a realistic
// `MusicXML.Score` (`MXLScorePartwise`) without hand-building the AST.
internal func parseMusicXMLScore(_ musicXML: String,
                                 sourceLocation: SourceLocation = #_sourceLocation) throws -> MusicXML.Score {
    let data = Data(musicXML.utf8)
    let document = try MusicXML.Parser().parse(data,
                                               compressed: false)

    guard case let .scorePartwise(score) = document.content
    else {
        Issue.record("Expected a score-partwise document",
                     sourceLocation: sourceLocation)

        throw MusicXML.Error.unsupportedScoreFormat("opus")
    }

    return score
}

internal func notes(in part: Part<BeatTime, Pitch>,
                    sourceLocation: SourceLocation = #_sourceLocation) -> [(attack: BeatTime, duration: BeatDuration, pitch: Pitch)] {
    var notes: [(attack: BeatTime, duration: BeatDuration, pitch: Pitch)] = []

    part.noteTable.forEach { _, attack, duration, startPitch, endPitch, _ in
        #expect(startPitch == endPitch,
                sourceLocation: sourceLocation)

        notes.append((attack, duration, startPitch))
    }

    return notes
}

internal func absoluteBeatParts(of work: Work) -> [Part<BeatTime, Frequency>]? {
    guard case let .absoluteBeat(parts, _) = work.content
    else { return nil }

    return parts
}

internal func keyboardBeatParts(of work: Work) -> [Part<BeatTime, NoteNumber>]? {
    guard case let .keyboardBeat(parts, _) = work.content
    else { return nil }

    return parts
}

internal func standardBeatParts(of work: Work) -> [Part<BeatTime, Pitch>]? {
    guard case let .standardBeat(parts, _) = work.content
    else { return nil }

    return parts
}

// Wraps `parts` in a minimal standard-beat `Work`, with an empty `TempoMap`.
// Shared by every exporter test that only cares about a single format's
// note-level output, not tempo.
internal func standardBeatWork(parts: [Part<BeatTime, Pitch>]) -> Work {
    Work(name: "Test",
         content: .standardBeat(parts, TempoMap()))
}

// Looks a part up by name rather than by index, so an ABC round trip stays
// resilient to part ordering. Used only by ABC-importing tests — see
// `ABCRoundTripTests`'s file comment for why `ABC.Importer.Walker`'s
// implicit "voice 0" accumulator never surfaces as a spurious extra part
// here.
internal func namedStandardPart(_ work: Work,
                                _ name: String,
                                sourceLocation: SourceLocation = #_sourceLocation) throws -> Part<BeatTime, Pitch> {
    try #require(standardBeatParts(of: work)?.first { $0.name == name },
                 sourceLocation: sourceLocation)
}

internal func decorations(in tune: ABCTune) -> [ABCDecoration] {
    symbols(in: tune).compactMap { symbol -> ABCDecoration? in
        guard case let .decoration(decoration) = symbol
        else { return nil }

        return decoration
    }
}

internal func symbols(in tune: ABCTune) -> [ABCSymbol] {
    tune.body.flatMap { entry -> [ABCSymbol] in
        guard case let .symbols(symbols) = entry
        else { return [] }

        return symbols
    }
}

internal func flatten(_ symbols: [GMNSymbol]) -> [GMNSymbol] {
    var result: [GMNSymbol] = []

    for symbol in symbols {
        result.append(symbol)

        switch symbol {
        case let .chord(chord):
            for segment in chord.segments {
                result += flatten(segment.symbols)
            }

        case let .tag(tag):
            result += flatten(tag.body)

        default:
            break
        }
    }

    return result
}

internal func instruments(in score: Guido.Score) -> [GMNInstrument] {
    symbols(in: score).compactMap { symbol -> GMNInstrument? in
        guard case let .tag(.instrument(instrument)) = symbol
        else { return nil }

        return instrument
    }
}

internal func intensities(in score: Guido.Score) -> [GMNIntensity] {
    symbols(in: score).compactMap { symbol -> GMNIntensity? in
        guard case let .tag(.intensity(intensity)) = symbol
        else { return nil }

        return intensity
    }
}

internal func symbols(in score: Guido.Score) -> [GMNSymbol] {
    score.voices.flatMap { flatten($0.symbols) }
}

internal func dynamicsItems(in score: MusicXML.Score) -> [MXLDynamics.Item] {
    directions(in: score).flatMap { direction in
        direction.kind.compactMap { kind -> [MXLDynamics.Item]? in
            guard case let .dynamics(marks) = kind.content
            else { return nil }

            return marks.flatMap(\.items)
        }.flatMap { $0 }
    }
}

internal func directions(in score: MusicXML.Score) -> [MXLDirection] {
    items(in: score).compactMap { item -> MXLDirection? in
        guard case let .direction(direction) = item
        else { return nil }

        return direction
    }
}

internal func isChord(_ note: MXLNote) -> Bool {
    guard case let .regularNote(fullNote, _, _) = note.content
    else { return false }

    return fullNote.isChord
}

internal func items(in score: MusicXML.Score) -> [MXLMusicItem] {
    score.parts.flatMap { $0.measures.flatMap(\.items) }
}

internal func notes(in score: MusicXML.Score) -> [MXLNote] {
    items(in: score).compactMap { item -> MXLNote? in
        guard case let .note(note) = item
        else { return nil }

        return note
    }
}

internal func pitchedNotes(in score: MusicXML.Score) -> [MXLNote] {
    notes(in: score).filter { pitch($0) != nil }
}

internal func pitch(_ note: MXLNote) -> MusicXML.Pitch? {
    guard case let .regularNote(fullNote, _, _) = note.content,
          case let .pitch(pitch) = fullNote.content
    else { return nil }

    return pitch
}

internal func sounds(in score: MusicXML.Score) -> [MXLSound] {
    directions(in: score).compactMap(\.sound)
}

internal func ties(_ note: MXLNote) -> [MXLStartStop] {
    guard case let .regularNote(_, _, tie) = note.content
    else { return [] }

    return tie.map(\.kind)
}

internal func wedges(in score: MusicXML.Score) -> [MXLWedge] {
    directions(in: score).flatMap { direction in
        direction.kind.compactMap { kind -> MXLWedge? in
            guard case let .wedge(wedge) = kind.content
            else { return nil }

            return wedge
        }
    }
}

// Rebuilds a `Pitch`-keyed note table as a `NoteNumber`-keyed one, converting
// every start pitch via `noteNumber(for:)`. Ending pitch is dropped, matching
// `expectNoteTablesMatch`'s own "start pitch wins" convention.
internal func asNoteNumbers(_ noteTable: NoteTable<BeatTime, Pitch>,
                            sourceLocation: SourceLocation = #_sourceLocation) throws -> NoteTable<BeatTime, NoteNumber> {
    var entries: [(attack: BeatTime, duration: BeatDuration, pitch: Pitch)] = []

    noteTable.forEach { _, attack, duration, startPitch, _, _ in
        entries.append((attack, duration, startPitch))
    }

    var result = NoteTable<BeatTime, NoteNumber>()

    for entry in entries {
        try result.insert(attack: entry.attack,
                          duration: entry.duration,
                          pitch: noteNumber(for: entry.pitch, sourceLocation: sourceLocation))
    }

    return result
}

internal func accidentalOffset(_ accidental: Pitch.Accidental) -> Int {
    switch accidental {
    case .doubleFlat:
        -2

    case .doubleSharp:
        2

    case .flat:
        -1

    case .natural:
        0

    case .sharp:
        1
    }
}

internal func letterSemitone(_ letter: Pitch.Letter) -> Int {
    switch letter {
    case .a:
        9

    case .b:
        11

    case .c:
        0

    case .d:
        2

    case .e:
        4

    case .f:
        5

    case .g:
        7
    }
}

// Converts a `Pitch` to the `NoteNumber` MIDI represents it as, using the
// standard SPN convention (C4 = 60). No such conversion exists in the
// library itself — `Pitch` and `NoteNumber` are two of the five pitch
// notations `Work.content` can carry, and nothing but an exporter/importer
// pair ever needs to cross between them — so this is test-only glue for the
// one cross-format leg that also crosses a pitch-notation boundary.
internal func noteNumber(for pitch: Pitch,
                         sourceLocation: SourceLocation = #_sourceLocation) throws -> NoteNumber {
    let raw = (pitch.octave.intValue + 1) * 12 + letterSemitone(pitch.letter) + accidentalOffset(pitch.accidental)
    let uintRaw = try #require(UInt(exactly: raw), sourceLocation: sourceLocation)

    return try #require(NoteNumber(uintValue: uintRaw), sourceLocation: sourceLocation)
}
