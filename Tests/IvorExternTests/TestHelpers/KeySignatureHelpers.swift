// © 2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import IvorModel
import IvorTiming
import IvorTuning
import Testing
import XestiNumbers
import XestiTools

// A key signature from its accidentals, in any order.
internal func customKeySignature(_ accidentals: [PitchClass]) throws -> KeySignature {
    try #require(KeySignature(accidentals: accidentals))
}

// The diatonic key signature with `fifths` sharps (or flats, when negative).
internal func keySignature(_ fifths: Int) throws -> KeySignature {
    try #require(KeySignature(fifths: fifths))
}

// Each entry of a key signature table as `"<beat time> <short form>"`, with
// ` <mode>` appended when it has a mode extra: `"0 2# minor"`, `"4 Bb F#"`.
internal func keySummary(_ table: KeySignatureTable?) -> [String] {
    guard let table
    else { return ["no table"] }

    return table.map { entry in
        let head = "\(simpleFraction(entry.beatTime.numberValue)) \(entry.keySignature.stringValue(ascii: true))"

        return stringValue(entry.extras, .keySignatureMode).map { "\(head) \($0)" } ?? head
    }
}

// A key signature table with an entry at each beat time, each with an
// optional mode extra.
internal func keyTable(_ entries: [(Number, KeySignature, String?)]) throws -> KeySignatureTable {
    var table = KeySignatureTable()

    for (time, keySignature, mode) in entries {
        try table.insert(beatTime: #require(BeatTime(numberValue: time)),
                         keySignature: keySignature,
                         extras: keySignatureModeExtras(mode))
    }

    return table
}

// A one-part keyboard-beat work with the given key signature table: a C4
// on every beat for `beats` quarter notes.
internal func keyedKeyboardWork(_ table: KeySignatureTable,
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

// A one-part standard-beat work with the given key signature table and
// pitches, one per quarter note from 0.
internal func keyedStandardWork(_ table: KeySignatureTable,
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
