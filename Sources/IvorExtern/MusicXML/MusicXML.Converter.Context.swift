// © 2025–2026 John Gary Pusey (see LICENSE.md)

internal import IvorModel
internal import IvorTiming
internal import IvorTuning

private import XestiNumbers

extension MusicXML.Converter {

    // MARK: Internal Nested Types

    internal struct Context {

        // MARK: Internal Instance Properties

        internal var currentBeatDuration: BeatDuration = .zero
        internal var currentBeatTime: BeatTime = .zero
        internal var currentDivisions: UInt = 1
        internal var currentStandardPitch: Pitch?
        internal var isChord: Bool = false
        internal var noteInProgress: Bool = false
        internal var noteTable: NoteTable<BeatTime, Pitch> = NoteTable()
        internal var previousBeatTime: BeatTime = .zero
    }
}

// MARK: -

extension MusicXML.Converter.Context {

    // MARK: Internal Instance Methods

    internal mutating func emitNoteInProgress() {
        guard noteInProgress
        else { return }

        if let tmpStandardPitch = currentStandardPitch {
            noteTable.insert(attack: isChord ? previousBeatTime : currentBeatTime,
                             duration: currentBeatDuration,
                             pitch: tmpStandardPitch)
        }

        if !isChord {
            previousBeatTime = currentBeatTime

            currentBeatTime += currentBeatDuration
        }

        currentBeatDuration = .zero
        currentStandardPitch = nil
        noteInProgress = false
    }

    internal func makeBeatDuration(_ divisions: UInt) -> BeatDuration {
        BeatDuration(Number(numerator: divisions,
                            denominator: currentDivisions))
    }
}
