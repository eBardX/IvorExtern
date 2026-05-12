internal import IvorModel
internal import IvorTiming
internal import IvorTuning

private import IvorMIDI
private import XestiTools

extension MIDI.Converter {

    // MARK: Internal Nested Types

    internal struct Context {

        // MARK: Internal Nested Types

        internal typealias PendingNote = (note: MIDI.Note, attackTime: MIDI.EventTime)

        // MARK: Internal Initializers

        internal init(beatMap: MIDI.BeatMap) {
            self.beatMap = beatMap
            self.noteTable = NoteTable()
            self.partName = ""
            self.pendingNotes = []
        }

        // MARK: Internal Instance Properties

        internal var beatMap: MIDI.BeatMap
        internal var noteTable: NoteTable<BeatTime, NoteNumber>
        internal var partName: String
        internal var pendingNotes: [PendingNote]
    }
}

// MARK: -

extension MIDI.Converter.Context {

    // MARK: Internal Instance Methods

    internal mutating func handleNoteOff(_ releaseTime: MIDI.EventTime,
                                         _ note: MIDI.Note) {
        guard let idx = pendingNotes.firstIndex(where: { note == $0.note })
        else { return }

        let attackTime = pendingNotes[idx].attackTime

        pendingNotes.remove(at: idx)

        let (release, _) = beatMap[releaseTime]
        let (attack, _) = beatMap[attackTime]

        noteTable.insert(attack: attack,
                         duration: release - attack,
                         pitch: NoteNumber(note.uintValue))
    }

    internal mutating func handleNoteOn(_ attackTime: MIDI.EventTime,
                                        _ note: MIDI.Note) {
        pendingNotes.append((note, attackTime))
    }
}
