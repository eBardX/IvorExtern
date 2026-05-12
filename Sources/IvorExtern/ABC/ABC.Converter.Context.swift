internal import IvorModel
internal import IvorTiming
internal import IvorTuning

extension ABC.Converter {

    // MARK: Internal Nested Types

    internal struct Context {

        // MARK: Internal Instance Properties

        internal var currentBeatTime: BeatTime = .zero
        internal var noteTable: NoteTable<BeatTime, Pitch> = NoteTable()
    }
}

// MARK: -

extension ABC.Converter.Context {

    // MARK: Internal Instance Methods

    internal mutating func advance(_ duration: BeatDuration) {
        currentBeatTime += duration
    }
}
