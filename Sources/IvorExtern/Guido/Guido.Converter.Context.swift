// © 2025–2026 John Gary Pusey (see LICENSE.md)

internal import IvorModel
internal import IvorTiming
internal import IvorTuning

extension Guido.Converter {

    // MARK: Internal Nested Types

    internal struct Context {

        // MARK: Internal Instance Properties

        internal var chordBeatDuration: BeatDuration = .zero
        internal var currentBeatTime: BeatTime = .zero
        internal var inChord: Bool = false
        internal var noteTable: NoteTable<BeatTime, Pitch> = NoteTable()
    }
}

// MARK: -

extension Guido.Converter.Context {

    // MARK: Internal Instance Methods

    internal mutating func advance(_ duration: BeatDuration) {
        if !inChord {
            currentBeatTime += duration
        } else if chordBeatDuration < duration {
            chordBeatDuration = duration
        }
    }

    internal mutating func beginChord() {
        chordBeatDuration = .zero
        inChord = true
    }

    internal mutating func endChord() {
        currentBeatTime += chordBeatDuration

        chordBeatDuration = .zero
        inChord = false
    }
}
