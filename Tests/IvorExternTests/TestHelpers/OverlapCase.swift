// © 2026 John Gary Pusey (see LICENSE.md)

import IvorModel
import IvorTiming
import IvorTuning
import Testing
import XestiNumbers

// Single-part works whose notes overlap without sharing both attack and
// duration, which the ABC, Guido and MusicXML exporters split and tie into
// chords (see `ExportSlice`). Each round-trips through all three formats
// unchanged.
internal enum OverlapCase {
    case heldAcrossBarLine
    case heldAcrossKeyChange
    case repeatedUnderHeld
    case threeOverlapping
}

// MARK: -

extension OverlapCase {

    // A 4/4 work in one part, `Piano`, with these notes.
    internal func work() throws -> Work {
        var noteTable = NoteTable<BeatTime, Pitch>()

        for (attack, duration, pitch) in notes {
            noteTable.insert(attack: BeatTime.zero + .quarter * Number(attack),
                             duration: .quarter * Number(duration),
                             pitch: Pitch(stringLiteral: pitch))
        }

        let keyTable = switch self {
        case .heldAcrossKeyChange:
            try keyTable([(0, key(0)), (Number(numerator: 1, denominator: 2), key(1))])

        default:
            KeyTable()
        }

        return try Work(name: "Overlap",
                        content: .standardBeat([Part(name: "Piano", noteTable: noteTable)],
                                               TempoMap(),
                                               meterTable(summary: ["0 4/4"]),
                                               keyTable))
    }

    // MARK: Private Instance Properties

    // Each note's attack and duration, in quarter notes.
    private var notes: [(Int, Int, String)] {
        switch self {
        case .heldAcrossBarLine:
            // C4 tied over the bar line while E4 starts under it, and is
            // itself tied over the bar line; G4 starts on the downbeat.
            [(2, 4, "C4"), (3, 2, "E4"), (4, 1, "G4")]

        case .heldAcrossKeyChange:
            // The key changes to G major at beat 2, under a held C4; the
            // F#4 after it is written without an accidental.
            [(0, 4, "C4"), (1, 2, "E4"), (3, 1, "F#4")]

        case .repeatedUnderHeld:
            // Repeated C4s under a held E4: only the E4 is tied, so each C4
            // keeps its own attack.
            [(0, 1, "C4"), (0, 3, "E4"), (1, 1, "C4"), (2, 1, "C4")]

        case .threeOverlapping:
            [(0, 3, "C4"), (1, 2, "E4"), (2, 2, "G4")]
        }
    }
}

// MARK: - CaseIterable

extension OverlapCase: CaseIterable {
}

// MARK: - Sendable

extension OverlapCase: Sendable {
}
