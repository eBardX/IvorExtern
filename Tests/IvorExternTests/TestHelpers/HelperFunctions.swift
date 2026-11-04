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

// Compares two instrument maps' (time, instrument) entries, in order,
// reporting which index diverges rather than just failing.
internal func expectInstrumentMapsMatch<TimeType: TimeProtocol>(_ recovered: InstrumentMap<TimeType>,
                                                                _ original: InstrumentMap<TimeType>,
                                                                sourceLocation: SourceLocation = #_sourceLocation) {
    let recoveredEntries = recovered.map { ($0.time, $0.instrument) }
    let originalEntries = original.map { ($0.time, $0.instrument) }

    #expect(recoveredEntries.count == originalEntries.count,
            "instrument map entry count mismatch",
            sourceLocation: sourceLocation)

    for index in 0..<min(recoveredEntries.count, originalEntries.count) {
        #expect(recoveredEntries[index].0 == originalEntries[index].0,
                "instrument map entry \(index) time mismatch",
                sourceLocation: sourceLocation)
        #expect(recoveredEntries[index].1 == originalEntries[index].1,
                "instrument map entry \(index) instrument mismatch",
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
    let file = try exporter.write(works: [work], as: fileFormat)
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
         instrumentMap: InstrumentMap())
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
    var instrumentMap = InstrumentMap<WallTime>()
    var noteTable = NoteTable<WallTime, NoteNumber>()

    instrumentMap.insert(time: .zero,
                         instrument: .vanilla)
    instrumentMap.insert(time: makeWallTime(2),
                         instrument: chocolateInstrument)

    noteTable.insert(attack: .zero,
                     duration: makeWallDuration(1),
                     pitch: makeNoteNumber(60))
    noteTable.insert(attack: makeWallTime(3),
                     duration: makeWallDuration(1),
                     pitch: makeNoteNumber(62))

    return Part<WallTime, NoteNumber>(name: "Part 1",
                                      noteTable: noteTable,
                                      instrumentMap: instrumentMap)
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

internal func instrumentMapExtras(_ part: Part<WallTime, NoteNumber>,
                                  at wallTime: WallTime) -> Extras? {
    var result: Extras?

    for entry in part.instrumentMap {
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
    var instrumentMap = InstrumentMap<BeatTime>()

    noteTable.insert(attack: .zero, duration: BeatDuration(1), pitch: NoteNumber(60))
    instrumentMap.insert(time: .zero,
                         instrument: Instrument("Flute"),
                         extras: Extras(elements: [Extra(name: Extra.instrumentName.name, values: [.string("Flauto 1")])]))

    let part = Part(name: "Melody",
                    noteTable: noteTable,
                    instrumentMap: instrumentMap)

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
    var instrumentMap = InstrumentMap<BeatTime>()

    instrumentMap.insert(time: .zero,
                         instrument: Instrument("Flute"),
                         extras: Extras(elements: [Extra(name: Extra.instrumentName.name, values: [.string("Flauto 1")]),
                                                   Extra(name: Extra.instrumentAbbreviation.name, values: [.string("Fl. 1")])]))

    let part = Part<BeatTime, Pitch>(name: "Flute",
                                     noteTable: NoteTable(),
                                     instrumentMap: instrumentMap)

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

// swiftlint:enable file_length
