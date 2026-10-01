// © 2026 John Gary Pusey (see LICENSE.md)

import Foundation
@testable import IvorExtern
import IvorModel
import IvorTiming
import IvorTuning
import Testing

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
