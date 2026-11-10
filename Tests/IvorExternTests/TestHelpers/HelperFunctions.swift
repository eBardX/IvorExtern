// © 2025–2026 John Gary Pusey (see LICENSE.md)

import Foundation
import IvorABC
@testable import IvorExtern
import IvorGMN
import IvorMIDI
import IvorModel
import IvorMXL
import IvorSMF
import IvorSMPTE
import IvorTiming
import IvorTuning
import Testing
import XestiNumbers
import XestiTools

// swiftlint:disable file_length

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

    for note in part.noteTable {
        #expect(note.startPitch == note.endPitch,
                sourceLocation: sourceLocation)

        notes.append((note.attack, note.duration, note.startPitch))
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

internal func keyboardWallParts(of work: Work) -> [Part<WallTime, NoteNumber>]? {
    guard case let .keyboardWall(parts) = work.content
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

internal func channelExtras(_ channel: Int) -> Extras {
    Extras(elements: [Extra(name: Extra.midiChannel.name, values: [.int(channel)])])
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

    for note in noteTable {
        entries.append((note.attack, note.duration, note.startPitch))
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

// Shared round-trip machinery for every format's exporter/importer pair.
// Generalizes the two hand-rolled round trips that predate this file
// (`MIDIFormatterTests.format_roundTrip_preservesNoteCount`,
// `JohnnySonicFormatterTests.format_roundTrip_preservesCommandCount`) so
// each new exporter gets an automated round-trip target for free.
//
// A format that is lossy by design does not fight these helpers — it just
// doesn't call the comparator for the piece it drops. `expectNoteTablesMatch`
// bakes in the one loss every format shares (a glissando's end pitch, per
// the "start pitch wins" rule), but a format-specific loss such as
// JohnnySonic's `/Tuning` context, or MIDI's release-velocity blend, is
// simply left unasserted by that format's own round-trip suite rather than
// forcing exact equality here.

// Compares two dynamic maps' (time, dynamic) entries, in order, reporting
// which index diverges rather than just failing.
internal func expectDynamicMapsMatch<TimeType: TimeProtocol>(_ recovered: DynamicMap<TimeType>,
                                                             _ original: DynamicMap<TimeType>,
                                                             sourceLocation: SourceLocation = #_sourceLocation) {
    let recoveredEntries = _entries(in: recovered)
    let originalEntries = _entries(in: original)

    #expect(recoveredEntries.count == originalEntries.count,
            "dynamic map entry count mismatch",
            sourceLocation: sourceLocation)

    for index in 0..<min(recoveredEntries.count, originalEntries.count) {
        #expect(recoveredEntries[index].0 == originalEntries[index].0,
                "dynamic map entry \(index) time mismatch",
                sourceLocation: sourceLocation)
        #expect(recoveredEntries[index].1 == originalEntries[index].1,
                "dynamic map entry \(index) dynamic mismatch",
                sourceLocation: sourceLocation)
    }
}

// Compares two instrument tables' (time, instrument) entries, in order,
// reporting which index diverges rather than just failing.
internal func expectInstrumentTablesMatch<TimeType: TimeProtocol>(_ recovered: InstrumentTable<TimeType>,
                                                                  _ original: InstrumentTable<TimeType>,
                                                                  sourceLocation: SourceLocation = #_sourceLocation) {
    let recoveredEntries = recovered.map { ($0.time, $0.instrument) }
    let originalEntries = original.map { ($0.time, $0.instrument) }

    #expect(recoveredEntries.count == originalEntries.count,
            "instrument table entry count mismatch",
            sourceLocation: sourceLocation)

    for index in 0..<min(recoveredEntries.count, originalEntries.count) {
        #expect(recoveredEntries[index].0 == originalEntries[index].0,
                "instrument table entry \(index) time mismatch",
                sourceLocation: sourceLocation)
        #expect(recoveredEntries[index].1 == originalEntries[index].1,
                "instrument table entry \(index) instrument mismatch",
                sourceLocation: sourceLocation)
    }
}

// Compares two note tables' (attack, duration, start pitch) triples, in
// order, reporting which index and which field diverges rather than just
// failing. Ending pitch is intentionally excluded — see the file comment.
internal func expectNoteTablesMatch<TimeType: TimeProtocol, PitchType: PitchProtocol>(_ recovered: NoteTable<TimeType, PitchType>,
                                                                                      _ original: NoteTable<TimeType, PitchType>,
                                                                                      sourceLocation: SourceLocation = #_sourceLocation) {
    let recoveredNotes = _notes(in: recovered)
    let originalNotes = _notes(in: original)

    #expect(recoveredNotes.count == originalNotes.count,
            "note count mismatch",
            sourceLocation: sourceLocation)

    for index in 0..<min(recoveredNotes.count, originalNotes.count) {
        #expect(recoveredNotes[index].attack == originalNotes[index].attack,
                "note \(index) attack mismatch",
                sourceLocation: sourceLocation)
        #expect(recoveredNotes[index].duration == originalNotes[index].duration,
                "note \(index) duration mismatch",
                sourceLocation: sourceLocation)
        #expect(recoveredNotes[index].pitch == originalNotes[index].pitch,
                "note \(index) pitch mismatch",
                sourceLocation: sourceLocation)
    }
}

// Compares two pan maps' (time, pan) entries, in order, reporting which
// index diverges rather than just failing.
internal func expectPanMapsMatch<TimeType: TimeProtocol>(_ recovered: PanMap<TimeType>,
                                                         _ original: PanMap<TimeType>,
                                                         sourceLocation: SourceLocation = #_sourceLocation) {
    let recoveredEntries = recovered.map { ($0.time, $0.pan) }
    let originalEntries = original.map { ($0.time, $0.pan) }

    #expect(recoveredEntries.count == originalEntries.count,
            "pan map entry count mismatch",
            sourceLocation: sourceLocation)

    for index in 0..<min(recoveredEntries.count, originalEntries.count) {
        #expect(recoveredEntries[index].0 == originalEntries[index].0,
                "pan map entry \(index) time mismatch",
                sourceLocation: sourceLocation)
        #expect(recoveredEntries[index].1 == originalEntries[index].1,
                "pan map entry \(index) pan mismatch",
                sourceLocation: sourceLocation)
    }
}

// Compares two tempo maps' (beat time, tempo) entries, in order, reporting
// which index diverges rather than just failing.
internal func expectTempoMapsMatch(_ recovered: TempoMap,
                                   _ original: TempoMap,
                                   sourceLocation: SourceLocation = #_sourceLocation) {
    let recoveredEntries = recovered.map { ($0.beatTime, $0.tempo) }
    let originalEntries = original.map { ($0.beatTime, $0.tempo) }

    #expect(recoveredEntries.count == originalEntries.count,
            "tempo map entry count mismatch",
            sourceLocation: sourceLocation)

    for index in 0..<min(recoveredEntries.count, originalEntries.count) {
        #expect(recoveredEntries[index].0 == originalEntries[index].0,
                "tempo map entry \(index) beat time mismatch",
                sourceLocation: sourceLocation)
        #expect(recoveredEntries[index].1 == originalEntries[index].1,
                "tempo map entry \(index) tempo mismatch",
                sourceLocation: sourceLocation)
    }
}

// Writes `work` through `exporter` as `fileFormat`, reads the resulting
// bytes back through the matching `importer`, and returns the recovered
// `Work`.
internal func roundTrip(_ work: Work,
                        exporter: some ExporterProtocol,
                        importer: some ImporterProtocol,
                        fileFormat: FileFormat,
                        sourceLocation: SourceLocation = #_sourceLocation) throws -> Work {
    let file = try exporter.write(works: [work], as: fileFormat, options: .default)
    let works = try importer.read(from: file, as: fileFormat)

    return try #require(works.first,
                        "Expected a recovered work",
                        sourceLocation: sourceLocation)
}

private func _entries<TimeType: TimeProtocol>(in dynamicMap: DynamicMap<TimeType>) -> [(TimeType, Dynamic)] {
    var entries: [(TimeType, Dynamic)] = []

    for entry in dynamicMap {
        entries.append((entry.time, entry.dynamic))
    }

    return entries
}

private typealias Note<TimeType: TimeProtocol, PitchType: PitchProtocol> = (attack: TimeType, duration: TimeType.DurationType, pitch: PitchType)

private func _notes<TimeType: TimeProtocol, PitchType: PitchProtocol>(in noteTable: NoteTable<TimeType, PitchType>) -> [Note<TimeType, PitchType>] {
    var notes: [Note<TimeType, PitchType>] = []

    for note in noteTable {
        notes.append((note.attack, note.duration, note.startPitch))
    }

    return notes
}

internal func abcNoteExtras(_ abc: String) throws -> [Extras?] {
    let (tunebook, _) = try ABC.BaseParser().parse(Data(abc.utf8))
    let tune = try #require(tunebook.tunes.first)
    let results = try ABC.Importer.Walker().walk(tune, fileHeader: tunebook.fileHeader)
    var extras: [Extras?] = []

    for note in results[0].context.noteTable {
        extras.append(note.extras)
    }

    return extras
}

internal func readABC(_ abc: String) throws -> Work {
    let works = try ABC.Importer().read(from: FileWrapper(regularFileWithContents: Data(abc.utf8)), as: .abc)

    return try #require(works.first)
}

internal func sampleABCInfo() -> Work.Info {
    Work.Info(title: "Aubade",
              subtitles: ["Dawn Song"],
              alternateTitles: ["Morning Piece"],
              parentWorkTitle: "Collected Pieces",
              dedication: "To my teacher\nwith thanks",
              credits: [Credit(name: "J. Smith", role: .composer),
                        Credit(name: "A. Poet", role: .lyricist),
                        Credit(name: "T. Scribe", role: .transcriber)].compactMap(\.self),
              rights: [RightsNotice(text: "© 1998 Acme"),
                       RightsNotice(text: "© 2001 T. Scribe", scope: .transcription)].compactMap(\.self),
              remarks: [Remark(text: "Collected in 1904\nby a fiddler", label: "history"),
                        Remark(text: "From a fiddler", label: "source"),
                        Remark(text: "A plain remark"),
                        Remark(text: "Wistful", label: "mood")].compactMap(\.self))
}

internal func writeABC(_ work: Work) throws -> String {
    let file = try ABC.Exporter().write(works: [work], as: .abc)
    let data = try #require(file.regularFileContents)

    return try #require(String(data: data, encoding: .utf8))
}

internal func emptyWork(_ timeBasis: TimeBasis,
                        _ pitchNotation: PitchNotation) -> Work {
    Work(name: "Work",
         content: .empty(timeBasis: timeBasis,
                         pitchNotation: pitchNotation))
}

internal func emptyPart(_ name: String) -> Part<BeatTime, Pitch> {
    Part(name: name,
         noteTable: NoteTable(),
         dynamicMap: DynamicMap(),
         instrumentTable: InstrumentTable())
}

internal let chocolateInstrument: Instrument = "Chocolate"

internal func isNoteMessage(_ message: MIDIChannelMessage) -> Bool {
    switch message {
    case .noteOff,
         .noteOn:
        true

    default:
        false
    }
}

internal func expressionValues(_ performance: WorkPerformance) -> [(time: WallTime, value: UInt)] {
    performance.events.compactMap { event in
        guard case let .controlChange(_, .expressionControllerMSB, value) = event.message
        else { return nil }

        return (event.time, value.uintValue)
    }
}

internal func messagesWithoutExpression(_ performance: WorkPerformance) -> [MIDIChannelMessage] {
    performance.events.map(\.message).filter {
        switch $0 {
        case .controlChange(_, .expressionControllerLSB, _),
             .controlChange(_, .expressionControllerMSB, _):
            false

        default:
            true
        }
    }
}

internal func noteOnVelocities(_ performance: WorkPerformance) -> [UInt] {
    performance.events.compactMap { event in
        guard case let .noteOn(_, _, velocity) = event.message
        else { return nil }

        return velocity.uintValue
    }
}

internal func panMessages(_ performance: WorkPerformance) -> [MIDIChannelMessage] {
    performance.events.map(\.message).filter {
        switch $0 {
        case .controlChange(_, .panLSB, _),
             .controlChange(_, .panMSB, _):
            true

        default:
            false
        }
    }
}

internal func patchAssignment(_ kind: Patch.Kind,
                              channel: Int? = nil) throws -> PatchTable.Assignment {
    let patch = try #require(Patch(kind))

    return try #require(PatchTable.Assignment(patch: patch,
                                              channel: channel))
}

// Each part is a list of notes as (attack, duration, key), in seconds.
//
internal func makeKeyboardWallParts(_ parts: [[(Double, Double, UInt)]]) -> [Part<WallTime, NoteNumber>] {
    parts.enumerated().map { offset, notes in
        var noteTable = NoteTable<WallTime, NoteNumber>()

        for (attack, duration, key) in notes {
            noteTable.insert(attack: makeWallTime(attack),
                             duration: makeWallDuration(duration),
                             pitch: makeNoteNumber(key))
        }

        return Part<WallTime, NoteNumber>(name: "Part \(offset + 1)",
                                          noteTable: noteTable)
    }
}

internal func makeKeyboardWallWork(_ parts: [[(Double, Double, UInt)]]) -> Work {
    Work(content: .keyboardWall(makeKeyboardWallParts(parts)))
}

internal func makeNoteNumber(_ uintValue: UInt) -> NoteNumber {
    // swiftlint:disable:next force_unwrapping
    NoteNumber(uintValue: uintValue)!
}

// `Vanilla` from the start, with a note at 0, then `Chocolate` from 2, with a note at 3.
//
internal func makeTwoInstrumentPart() -> Part<WallTime, NoteNumber> {
    var instrumentTable = InstrumentTable<WallTime>()
    var noteTable = NoteTable<WallTime, NoteNumber>()

    instrumentTable.insert(time: .zero,
                           instrument: .vanilla)
    instrumentTable.insert(time: makeWallTime(2),
                           instrument: chocolateInstrument)

    noteTable.insert(attack: .zero,
                     duration: makeWallDuration(1),
                     pitch: makeNoteNumber(60))
    noteTable.insert(attack: makeWallTime(3),
                     duration: makeWallDuration(1),
                     pitch: makeNoteNumber(62))

    return Part<WallTime, NoteNumber>(name: "Part 1",
                                      noteTable: noteTable,
                                      instrumentTable: instrumentTable)
}

internal func makeWallDuration(_ seconds: Double) -> WallDuration {
    // swiftlint:disable:next force_unwrapping
    WallDuration(uintValue: UInt((seconds * 1_000_000).rounded()))!
}

internal func makeWallTime(_ seconds: Double) -> WallTime {
    // swiftlint:disable:next force_unwrapping
    WallTime(uintValue: UInt((seconds * 1_000_000).rounded()))!
}

internal func readGuido(_ gmn: String) throws -> Work {
    try Guido.Importer().convert(Guido.Parser().parse(Data(gmn.utf8)))
}

internal func sampleGuidoInfo() -> Work.Info {
    Work.Info(title: "Aubade",
              subtitles: ["Dawn Song"],
              alternateTitles: ["Morning Piece"],
              parentWorkTitle: "Collected Pieces",
              dedication: "To my teacher",
              credits: [Credit(name: "J. Smith", role: .composer),
                        Credit(name: "A. Poet", role: .lyricist)].compactMap(\.self),
              rights: [RightsNotice(text: "© 1998 Acme\nLine two")].compactMap(\.self),
              remarks: [Remark(text: "Engraved by hand", label: "footer"),
                        Remark(text: "Theme", label: "label"),
                        Remark(text: "Dropped", label: "history")].compactMap(\.self))
}

internal func smpteOffsets(in sequence: MIDI.Sequence) -> [SMPTETime] {
    sequence.tracks[0].events.compactMap { event -> SMPTETime? in
        guard case let .meta(.zero, .smpteOffset(offset)) = event
        else { return nil }

        return offset
    }
}

internal func timeCodeExtras(_ frameRate: String,
                             _ ticksPerFrame: Int) -> Extras {
    Extras(elements: [Extra(name: Extra.midiTimeCode.name,
                            values: [.string(frameRate), .int(ticksPerFrame)])])
}

internal func unnamedPartNames(_ track: SMFTrack) throws -> [String] {
    let sequence = SMFSequence(format: .format1,
                               division: .metrical(SMFTickRate(480)),
                               tracks: [track])
    let work = try MIDI.Importer().convert(sequence)

    guard case let .keyboardBeat(parts, _) = work.content
    else { Issue.record("Expected keyboardBeat content"); return [] }

    return parts.map(\.name)
}

internal func instrumentTableExtras(_ part: Part<WallTime, NoteNumber>,
                                    at wallTime: WallTime) -> Extras? {
    var result: Extras?

    for entry in part.instrumentTable {
        if result == nil, entry.time == wallTime {
            result = entry.extras
        }
    }

    return result
}

internal func tempoMapExtras(_ work: Work,
                             at beatTime: BeatTime) -> Extras? {
    work.tempoMap?.first { $0.beatTime == beatTime }?.extras
}

internal func timeCodeValues(_ extras: Extras?) -> [Extra.AssociatedValue]? {
    extras?.elements.first { $0.name == Extra.midiTimeCode.name }?.values
}

internal func sampleMIDIWork() -> Work {
    var noteTable = NoteTable<BeatTime, NoteNumber>()
    var instrumentTable = InstrumentTable<BeatTime>()

    noteTable.insert(attack: .zero, duration: BeatDuration(1), pitch: NoteNumber(60))
    instrumentTable.insert(time: .zero,
                           instrument: Instrument("Flute"),
                           extras: Extras(elements: [Extra(name: Extra.instrumentName.name, values: [.string("Flauto 1")])]))

    let part = Part(name: "Melody",
                    noteTable: noteTable,
                    instrumentTable: instrumentTable)

    return Work(name: "Sketch",
                content: .keyboardBeat([part], TempoMap()),
                info: Work.Info(title: "Aubade",
                                subtitles: ["Dawn Song"],
                                dedication: "To my teacher\nwith thanks",
                                credits: [Credit(name: "J. Smith", role: .composer)].compactMap(\.self),
                                rights: [RightsNotice(text: "© 1998 Acme"),
                                         RightsNotice(text: "℗ 1999 Acme")].compactMap(\.self),
                                remarks: [Remark(text: "Written at dawn", label: "history")].compactMap(\.self)))
}

internal func makeNoteTrack() -> SMFTrack {
    let key = MIDIData1Value(60)

    return SMFTrack(events: [.midi(SMFEventTime(100), .noteOn(MIDIChannel(1), key, MIDIData1Value(100))),
                             .midi(SMFEventTime(200), .noteOff(MIDIChannel(1), key, MIDIData1Value(64))),
                             .meta(SMFEventTime(200), .endOfTrack)])
}

internal func readMusicXML(header: String,
                           scorePart: String = "<part-name>Piano</part-name>") throws -> Work {
    let musicXML = """
        <?xml version="1.0" encoding="UTF-8"?>
        <score-partwise version="4.0">
        \(header)
          <part-list>
            <score-part id="P1">\(scorePart)</score-part>
          </part-list>
          <part id="P1">
            <measure number="1">
              <attributes><divisions>1</divisions></attributes>
              <note>
                <pitch><step>C</step><octave>5</octave></pitch>
                <duration>1</duration>
                <type>quarter</type>
              </note>
            </measure>
          </part>
        </score-partwise>
        """
    let works = try MusicXML.Importer().read(from: FileWrapper(regularFileWithContents: Data(musicXML.utf8)), as: .musicXML)

    return try #require(works.first)
}

internal func sampleMusicXMLWork() -> Work {
    var instrumentTable = InstrumentTable<BeatTime>()

    instrumentTable.insert(time: .zero,
                           instrument: Instrument("Flute"),
                           extras: Extras(elements: [Extra(name: Extra.instrumentName.name, values: [.string("Flauto 1")]),
                                                     Extra(name: Extra.instrumentAbbreviation.name, values: [.string("Fl. 1")])]))

    let part = Part<BeatTime, Pitch>(name: "Flute",
                                     noteTable: NoteTable(),
                                     instrumentTable: instrumentTable)

    return Work(name: "Collected Pieces: Aubade",
                content: .standardBeat([part], TempoMap()),
                info: Work.Info(title: "Aubade",
                                subtitles: ["Dawn Song"],
                                alternateTitles: ["Morning Piece"],
                                parentWorkTitle: "Collected Pieces",
                                dedication: "To my teacher",
                                credits: [Credit(name: "J. Smith", role: .composer),
                                          Credit(name: "A. Poet", role: .lyricist),
                                          Credit(name: "T. Scribe", role: .transcriber)].compactMap(\.self),
                                rights: [RightsNotice(text: "© 1998 Acme\nLine two", scope: .music)].compactMap(\.self),
                                remarks: [Remark(text: "From a fiddler", label: "source"),
                                          Remark(text: "A plain remark"),
                                          Remark(text: "Op. 2", label: "work number")].compactMap(\.self)))
}

// A dynamic map holding `entries` as (beat time, dynamic), in order.
internal func makeDynamicMap(_ entries: [(Number, Dynamic)]) -> DynamicMap<BeatTime> {
    var dynamicMap = DynamicMap<BeatTime>()

    for (time, dynamic) in entries {
        dynamicMap.insert(time: BeatTime(time),
                          dynamic: dynamic)
    }

    return dynamicMap
}

// The shapes of `dynamicMap`, each as one line of text, for comparing against
// a literal: `"mark 0 p"`, `"mark 4 p sfz"`, or `"ramp 4 p 8 f"`.
internal func dynamicShapeSummary(_ dynamicMap: DynamicMap<BeatTime>) -> [String] {
    func beat(_ time: BeatTime) -> String {
        [(BeatTime(0), "0"), (BeatTime(4), "4"), (BeatTime(8), "8")].first { $0.0 == time }?.1 ?? "?"
    }

    func name(_ dynamic: Dynamic) -> String {
        [(Dynamic.p, "p"), (.mf, "mf"), (.f, "f"), (.ff, "ff")].first { $0.0 == dynamic }?.1 ?? "?"
    }

    return DynamicShape.shapes(of: dynamicMap).map {
        switch $0 {
        case let .mark(time, dynamic, mark):
            "mark \(beat(time)) \(name(dynamic))" + (mark.map { " \($0)" } ?? "")

        case let .ramp(start, startDynamic, end, endDynamic):
            "ramp \(beat(start)) \(name(startDynamic)) \(beat(end)) \(name(endDynamic))"
        }
    }
}

// Walks a one-part, one-measure score holding `items`, after an `<attributes>`
// setting one division per quarter note.
internal func walkMusicXMLMeasure(_ items: String) throws -> [MusicXML.Importer.Walker.WalkResult] {
    let musicXML = """
        <?xml version="1.0" encoding="UTF-8"?>
        <score-partwise version="4.0">
          <part-list>
            <score-part id="P1"><part-name>P</part-name></score-part>
          </part-list>
          <part id="P1">
            <measure number="1">
              <attributes><divisions>1</divisions></attributes>
              \(items)
            </measure>
          </part>
        </score-partwise>
        """

    return try MusicXML.Importer.Walker().walk(parseMusicXMLScore(musicXML),
                                               order: [0])
}

// The extras of a lone C4 walked with `notations` as its `<notations>` content.
internal func walkedExtras(notations: String,
                           sourceLocation: SourceLocation = #_sourceLocation) throws -> Extras? {
    let results = try walkMusicXMLMeasure("""
        <note>
          <pitch><step>C</step><octave>4</octave></pitch>
          <duration>1</duration>
          <notations>\(notations)</notations>
        </note>
        """)
    let voice = try #require(results.first?.part.voices.first,
                             sourceLocation: sourceLocation)

    return voice.noteTable.map(\.extras).first.flatMap(\.self)
}

// A score of four measures: a C4 filling the first, under `time` (a `<time>`
// element, or nothing), then a `<multiple-rest>` of two empty measures, then
// another C4.
internal func multipleRestMusicXML(time: String) -> String {
    """
    <?xml version="1.0" encoding="UTF-8"?>
    <score-partwise version="4.0">
      <part-list>
        <score-part id="P1"><part-name>P</part-name></score-part>
      </part-list>
      <part id="P1">
        <measure number="1">
          <attributes>
            <divisions>1</divisions>
            \(time)
          </attributes>
          <note>
            <pitch><step>C</step><octave>4</octave></pitch>
            <duration>4</duration>
          </note>
        </measure>
        <measure number="2">
          <attributes>
            <measure-style><multiple-rest>2</multiple-rest></measure-style>
          </attributes>
        </measure>
        <measure number="3"/>
        <measure number="4">
          <note>
            <pitch><step>C</step><octave>4</octave></pitch>
            <duration>1</duration>
          </note>
        </measure>
      </part>
    </score-partwise>
    """
}

// The extras of a lone C4 carrying `extras` after a trip out through
// `MusicXML.Exporter` and back in through `MusicXML.Importer`.
internal func roundTripNoteExtras(_ extras: Extras,
                                  sourceLocation: SourceLocation = #_sourceLocation) throws -> Extras? {
    var noteTable = NoteTable<BeatTime, Pitch>()

    noteTable.insert(attack: .zero,
                     duration: BeatDuration(1),
                     pitch: "C4",
                     extras: extras)

    let recovered = try roundTrip(standardBeatWork(parts: [Part(name: "P", noteTable: noteTable)]),
                                  exporter: MusicXML.Exporter(),
                                  importer: MusicXML.Importer(),
                                  fileFormat: .musicXML,
                                  sourceLocation: sourceLocation)
    let part = try #require(standardBeatParts(of: recovered)?.first,
                            sourceLocation: sourceLocation)

    return part.noteTable.map(\.extras).first.flatMap(\.self)
}

// A note at octave 1 for tests that build `GMNSymbol`s by hand. A `nil`
// `duration` writes none, so the note inherits the sticky one.
internal func makeGMNNote(name: GMNPitch.Name = .c,
                          accidental: GMNPitch.Accidental = .omitted,
                          duration: GMNDuration? = GMNDuration(numerator: 1, denominator: 4),
                          sourceLocation: SourceLocation = #_sourceLocation) throws -> GMNNote {
    let octave = try #require(GMNPitch.Octave(intValue: 1),
                              sourceLocation: sourceLocation)

    return GMNNote(pitch: GMNPitch(name: name, accidental: accidental, octave: octave),
                   duration: duration)
}

// Walks one voice of `symbols`, with no variables declared.
internal func walkGMN(_ symbols: [GMNSymbol]) throws -> Guido.Importer.Context {
    try Guido.Importer.Walker(variables: [:]).walk(Guido.Voice(symbols: symbols))
}

// A match of the transposing macro `Tn = replacement` against a C4.
internal func makeABCMacroMatch(replacement: String,
                                sourceLocation: SourceLocation = #_sourceLocation) throws -> ABC.Importer.MacroTable.Match {
    let macro = try #require(ABCMacro(target: "Tn", replacement: replacement),
                             sourceLocation: sourceLocation)
    let octave = try #require(ABCPitch.Octave(uintValue: 4),
                              sourceLocation: sourceLocation)
    let length = try #require(ABCLength(numerator: 1),
                              sourceLocation: sourceLocation)
    let note = ABCNote(pitch: ABCPitch(letter: .c, accidental: .natural, octave: octave),
                       length: length,
                       tie: nil)

    return ABC.Importer.MacroTable.Match(consumedCount: 1,
                                         macro: macro,
                                         matchedNote: note)
}

// The letters of the notes in the ABC tune body `text`, in the order
// `ABC.Importer.Plan` plays them.
internal func plannedLetters(_ text: String) throws -> String {
    let items = try abcSymbols(from: text).map { ABC.Importer.Item.symbol($0) }
    let ranges = try ABC.Importer.Plan(items: items).ranges()

    return ranges.flatMap { items[$0] }.compactMap { item -> String? in
        guard case let .symbol(.note(note)) = item
        else { return nil }

        return String(describing: note.pitch.letter).uppercased()
    }.joined()
}

// The play order of a one-part score whose measures hold `measures`.
internal func plannedOrder(_ measures: [String]) throws -> [Int] {
    let items = measures.enumerated().map { index, measure in
        "<measure number=\"\(index + 1)\">\(measure)</measure>"
    }
    let musicXML = """
        <?xml version="1.0" encoding="UTF-8"?>
        <score-partwise version="4.0">
          <part-list>
            <score-part id="P1"><part-name>P</part-name></score-part>
          </part-list>
          <part id="P1">\(items.joined())</part>
        </score-partwise>
        """

    return try MusicXML.Importer.Plan(parseMusicXMLScore(musicXML)).order
}

// One measure's `<ending>` of `number`, closed by a backward repeat.
internal func firstEnding(_ number: Int) -> String {
    """
    <barline location="left"><ending number="\(number)" type="start"/></barline>\
    <barline location="right"><ending number="\(number)" type="stop"/><repeat direction="backward"/></barline>
    """
}

// One measure's `<ending>` of `number`, with no repeat to close it.
internal func lastEnding(_ number: Int) -> String {
    """
    <barline location="left"><ending number="\(number)" type="start"/></barline>\
    <barline location="right"><ending number="\(number)" type="discontinue"/></barline>
    """
}

// A note of `duration` divisions on `step`, in octave 4, as MusicXML text.
internal func musicXMLNote(_ step: String,
                           duration: Int = 4) -> String {
    "<note><pitch><step>\(step)</step><octave>4</octave></pitch><duration>\(duration)</duration></note>"
}

// The notes a one-part score whose measures hold `measures` plays, in its
// `Plan`'s order, each as its step and beat: `"C@4"`.
internal func playedNotes(_ measures: [String]) throws -> [String] {
    let items = measures.enumerated().map { index, measure in
        "<measure number=\"\(index + 1)\">\(measure)</measure>"
    }
    let musicXML = """
        <?xml version="1.0" encoding="UTF-8"?>
        <score-partwise version="4.0">
          <part-list>
            <score-part id="P1"><part-name>P</part-name></score-part>
          </part-list>
          <part id="P1">\(items.joined())</part>
        </score-partwise>
        """
    let score = try parseMusicXMLScore(musicXML)
    let results = try MusicXML.Importer.Walker().walk(score,
                                                      order: MusicXML.Importer.Plan(score).order)

    return results.flatMap(\.part.voices).flatMap { voice in
        voice.noteTable.map { "\($0.startPitch.pitchClass.letter)".uppercased() + "@\(Int($0.attack.doubleValue))" }
    }
}

// An `<attributes>` starting a `<measure-repeat>` of `length` measures.
internal func repeatStart(_ length: Int) -> String {
    #"<attributes><measure-style><measure-repeat type="start">\#(length)</measure-repeat></measure-style></attributes>"#
}

internal func abcPedalPart(_ body: String) throws -> Part<BeatTime, Pitch> {
    let work = try readABC("""
        X:1
        T:Test
        M:4/4
        L:1/4
        K:C
        \(body)
        """)

    guard case let .standardBeat(parts, _) = work.content
    else { Issue.record("Expected standardBeat content"); throw CancellationError() }

    return try #require(parts.first)
}

internal func guidoPedalPart(_ gmn: String) throws -> Part<BeatTime, Pitch> {
    let work = try Guido.Importer().convert(Guido.Parser().parse(Data(gmn.utf8)))

    guard case let .standardBeat(parts, _) = work.content
    else { Issue.record("Expected standardBeat content"); throw CancellationError() }

    return try #require(parts.first)
}

// Imports one channel-1 track with a note at tick 0 plus the given
// controller events (tick, controller, value) at 480 ticks per beat.
internal func midiImportedPedals(_ events: [(tick: UInt, controller: MIDIController, value: UInt)]) throws -> [Pedal: PedalTable<BeatTime>] {
    let channel = MIDIChannel(1)
    let key = MIDIData1Value(60)
    var smfEvents: [SMFEvent] = [.midi(.zero, .noteOn(channel, key, MIDIData1Value(100)))]

    for event in events {
        smfEvents.append(.midi(SMFEventTime(event.tick),
                               .controlChange(channel, event.controller, MIDIData1Value(clamping: event.value))))
    }

    smfEvents.append(.midi(SMFEventTime(1_440), .noteOff(channel, key, MIDIData1Value(64))))
    smfEvents.append(.meta(SMFEventTime(1_440), .endOfTrack))

    let sequence = SMFSequence(format: .format1,
                               division: .metrical(SMFTickRate(480)),
                               tracks: [SMFTrack(events: smfEvents)])
    let work = try MIDI.Importer().convert(sequence)

    guard case let .keyboardBeat(parts, _) = work.content
    else { Issue.record("Expected keyboardBeat content"); return [:] }

    return try #require(parts.first).pedals
}

// One part of quarter notes. Before note i come `marks[i]` (as a
// `<direction>` whose `<sound>` is `directionSounds[i]`, if any) and
// `sounds[i]` (as a bare `<sound>`).
internal func musicXMLImportedPedals(_ marks: [String],
                                     directionSounds: [String] = [],
                                     sounds: [String] = []) throws -> [Pedal: PedalTable<BeatTime>] {
    let count = max(marks.count, directionSounds.count, sounds.count, 1)
    var body = ""

    for index in 0..<count {
        let mark = index < marks.count ? marks[index] : nil
        let directionSound = index < directionSounds.count ? directionSounds[index] : nil

        if let mark {
            body += "<direction><direction-type>\(mark)</direction-type>\(directionSound ?? "")</direction>\n"
        }

        if index < sounds.count {
            body += sounds[index] + "\n"
        }

        body += "<note><pitch><step>C</step><octave>5</octave></pitch><duration>1</duration><type>quarter</type></note>\n"
    }

    let musicXML = """
        <?xml version="1.0" encoding="UTF-8"?>
        <score-partwise version="4.0">
          <part-list><score-part id="P1"><part-name>Piano</part-name></score-part></part-list>
          <part id="P1">
            <measure number="1">
              <attributes><divisions>1</divisions></attributes>
              \(body)
            </measure>
          </part>
        </score-partwise>
        """

    return try #require(musicXMLImportedParts(musicXML).first).pedals
}

internal func musicXMLImportedParts(_ musicXML: String) throws -> [Part<BeatTime, Pitch>] {
    let works = try MusicXML.Importer().read(from: FileWrapper(regularFileWithContents: Data(musicXML.utf8)),
                                             as: .musicXML)
    let work = try #require(works.first)

    guard case let .standardBeat(parts, _) = work.content
    else { Issue.record("Expected standardBeat content"); return [] }

    return parts
}

// One part of quarter notes C D E F with the given pedals.
internal func abcExportedWithPedals(_ pedals: [Pedal: PedalTable<BeatTime>]) throws -> String {
    var noteTable = NoteTable<BeatTime, Pitch>()

    for (index, pitch) in [Pitch.c4, .d4, .e4, .f4].enumerated() {
        noteTable.insert(attack: BeatTime(Number(index)), duration: 1, pitch: pitch)
    }

    return try writeABC(standardBeatWork(parts: [Part(name: "Piano", noteTable: noteTable, pedals: pedals)]))
}

// The CC 64–68 events in the exported track of one keyboard part with a
// note from 0 to 4 and the given pedals, in file order.
internal func midiExportedPedalEvents(_ pedals: [Pedal: PedalTable<BeatTime>]) throws -> [(tick: UInt, controller: MIDIController, value: UInt)] {
    var noteTable = NoteTable<BeatTime, NoteNumber>()

    noteTable.insert(attack: 0, duration: 4, pitch: NoteNumber(60))

    let part = Part<BeatTime, NoteNumber>(name: "Piano", noteTable: noteTable, pedals: pedals)
    let sequence = try MIDI.Exporter().convert(Work(name: "Test", content: .keyboardBeat([part], TempoMap())))

    return sequence.tracks.flatMap(\.events).compactMap { event in
        guard case let .midi(eventTime, .controlChange(_, controller, value)) = event,
              convertToPedal(controller) != nil
        else { return nil }

        return (tick: eventTime.uintValue, controller: controller, value: value.uintValue)
    }
}

internal func guidoExportedPedalKinds(_ pedals: [Pedal: PedalTable<BeatTime>]) throws -> [GMNPedal.Kind] {
    var noteTable = NoteTable<BeatTime, Pitch>()

    noteTable.insert(attack: 0, duration: 4, pitch: .c4)

    let part = Part<BeatTime, Pitch>(name: "Piano", noteTable: noteTable, pedals: pedals)
    let score = try Guido.Exporter().convert(standardBeatWork(parts: [part]))

    return symbols(in: score).compactMap { symbol in
        guard case let .tag(.pedal(pedal)) = symbol
        else { return nil }

        return pedal.kind
    }
}

internal func musicXMLExportedPedalDirections(_ pedals: [Pedal: PedalTable<BeatTime>]) throws -> [ExportedPedalDirection] {
    var noteTable = NoteTable<BeatTime, Pitch>()

    noteTable.insert(attack: 0, duration: 4, pitch: .c4)

    let part = Part<BeatTime, Pitch>(name: "Piano", noteTable: noteTable, pedals: pedals)
    let score = try MusicXML.Exporter().convert(standardBeatWork(parts: [part]))

    return directions(in: score).compactMap { direction in
        let marks = direction.kind.compactMap { kind -> MXLPedal? in
            guard case let .pedal(pedal) = kind.content
            else { return nil }

            return pedal
        }
        let sound = direction.sound

        guard !marks.isEmpty || sound?.damperPedal != nil || sound?.softPedal != nil || sound?.sostenutoPedal != nil
        else { return nil }

        return ExportedPedalDirection(pedals: marks, sound: sound)
    }
}

internal func pedalMessages(_ performance: WorkPerformance) -> [MIDIChannelMessage] {
    performance.events.map(\.message).filter {
        guard case let .controlChange(_, controller, _) = $0
        else { return false }

        return (64...68).contains(controller.uintValue)
    }
}

// `levels` as (seconds, level).
internal func wallSustainTable(_ levels: [(Double, Pedal.Level)]) -> PedalTable<WallTime> {
    var table = PedalTable<WallTime>()

    for (seconds, level) in levels {
        table.insert(time: makeWallTime(seconds), level: level)
    }

    return table
}

// Each pedal's entries as "level @ time" (plain forms), of a work's only part.
internal func pedalSummary(_ parts: [Part<BeatTime, some PitchProtocol>]?) throws -> [Pedal: [String]] {
    let part = try #require(parts?.first)

    return part.pedals.mapValues { table in
        table.map { "\($0.level.plain) @ \($0.time.plain)" }
    }
}

// A `<direction>` carrying the given `<pedal>` marks and, optionally, a
// `<sound>`.
internal func pedalDirection(_ marks: [MXLPedal],
                             sound: MXLSound? = nil) -> MXLDirection {
    MXLDirection(kind: marks.map { MXLDirection.Kind(content: .pedal($0)) },
                 sound: sound)
}

// A sustain table of the given (beat, level) entries, in order.
internal func beatSustainTable(_ levels: [(BeatTime, Pedal.Level)]) -> PedalTable<BeatTime> {
    var table = PedalTable<BeatTime>()

    for (time, level) in levels {
        table.insert(time: time, level: level)
    }

    return table
}

// The `<pedal>` marks in `direction`, in order.
internal func pedalMarks(_ direction: MXLDirection) -> [MXLPedal] {
    direction.kind.compactMap { kind in
        guard case let .pedal(pedal) = kind.content
        else { return nil }

        return pedal
    }
}

// swiftlint:enable file_length
