// © 2026 John Gary Pusey (see LICENSE.md)

import Foundation
@testable import IvorExtern
import IvorModel
import IvorTiming
import IvorTuning
import Testing
import XestiNumbers
import XestiTools

// The key a written signature gives, from its accidentals in any order:
// diatonic with no mode for a diatonic set, otherwise custom.
internal func customKey(_ accidentals: [PitchClass]) throws -> Key {
    try #require(Key(accidentals: accidentals))
}

// The diatonic key with `fifths` sharps (or flats, when negative), in
// `mode`, or with no mode.
internal func key(_ fifths: Int,
                  _ mode: Key.Mode? = nil) throws -> Key {
    try #require(Key.diatonic(fifths: fifths,
                              mode: mode))
}

// Each entry of a key table as `"<beat time> <full name>"`, in ASCII:
// `"0 B minor"`, `"2 F# C#"`, `"4 Bb F#"`, `"6 Atonal"`.
internal func keySummary(_ table: KeyTable?) -> [String] {
    guard let table
    else { return ["no table"] }

    return table.map { entry in
        "\(simpleFraction(entry.beatTime.numberValue)) \(String(entry.key.formatted(Key.FormatStyle(ascii: true)).characters))"
    }
}

// A key table with an entry at each beat time.
internal func keyTable(_ entries: [(Number, Key)]) throws -> KeyTable {
    var table = KeyTable()

    for (time, key) in entries {
        try table.insert(beatTime: #require(BeatTime(numberValue: time)),
                         key: key)
    }

    return table
}

// A one-part keyboard-beat work with the given key table: a C4
// on every beat for `beats` quarter notes.
internal func keyedKeyboardWork(_ table: KeyTable,
                                beats: Int = 8) -> Work {
    var noteTable = NoteTable<BeatTime, NoteNumber>()

    for beat in 0..<beats {
        noteTable.insert(attack: BeatTime.zero + .quarter * Number(beat),
                         duration: .quarter,
                         pitch: NoteNumber(60))
    }

    return Work(name: "Keyed",
                content: .keyboardBeat([Part(name: "Piano", noteTable: noteTable)],
                                       TempoMap(),
                                       MeterTable(),
                                       table))
}

// A one-part standard-beat work with the given key table and
// pitches, one per quarter note from 0.
internal func keyedStandardWork(_ table: KeyTable,
                                pitches: [Pitch],
                                meterTable: MeterTable = MeterTable()) -> Work {
    var noteTable = NoteTable<BeatTime, Pitch>()

    for (index, pitch) in pitches.enumerated() {
        noteTable.insert(attack: BeatTime.zero + .quarter * Number(index),
                         duration: .quarter,
                         pitch: pitch)
    }

    return Work(name: "Keyed",
                content: .standardBeat([Part(name: "Piano", noteTable: noteTable)],
                                       TempoMap(),
                                       meterTable,
                                       table))
}
