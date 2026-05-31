// © 2025–2026 John Gary Pusey (see LICENSE.md)

internal import IvorModel
internal import IvorTiming
internal import IvorTuning

private import IvorMIDI
private import XestiNumbers
private import XestiTools

extension MIDI.Importer {

    // MARK: Internal Nested Types

    internal struct Context {

        // MARK: Internal Nested Types

        internal typealias PendingNote = (note: MIDI.NoteNumber, attackTime: MIDI.EventTime, velocity: MIDI.KeyVelocity)

        // MARK: Internal Initializers

        internal init(beatMap: MIDI.BeatMap) {
            self.beatMap = beatMap
            self.dynamicMap = DynamicMap()
            self.noteTable = NoteTable()
            self.panMap = PanMap()
            self.partName = ""
            self.pendingNotes = []
        }

        // MARK: Internal Instance Properties

        internal var beatMap: MIDI.BeatMap
        internal var dynamicMap: DynamicMap<BeatTime>
        internal var noteTable: NoteTable<BeatTime, NoteNumber>
        internal var panMap: PanMap<BeatTime>
        internal var partName: String
        internal var pendingNotes: [PendingNote]
    }
}

// MARK: -

extension MIDI.Importer.Context {

    // MARK: Internal Instance Methods

    internal mutating func handleNoteOff(_ releaseTime: MIDI.EventTime,
                                         _ note: MIDI.NoteNumber) {
        guard let idx = pendingNotes.firstIndex(where: { note == $0.note })
        else { return }

        let attackTime = pendingNotes[idx].attackTime
        let velocity = pendingNotes[idx].velocity

        pendingNotes.remove(at: idx)

        let (release, _) = beatMap[releaseTime]
        let (attack, _) = beatMap[attackTime]

        noteTable.insert(attack: attack,
                         duration: release - attack,
                         pitch: NoteNumber(note.uintValue))

        if let dynamic = Dynamic(numberValue: Number(Double(velocity.uintValue) / 127.0)) {
            dynamicMap.insert(time: attack,
                              dynamic: dynamic)
        }
    }

    internal mutating func handleNoteOn(_ attackTime: MIDI.EventTime,
                                        _ note: MIDI.NoteNumber,
                                        _ velocity: MIDI.KeyVelocity) {
        pendingNotes.append((note, attackTime, velocity))
    }

    internal mutating func handlePan(_ eventTime: MIDI.EventTime,
                                     _ value: MIDI.PanValue) {
        let (beatTime, _) = beatMap[eventTime]

        if let pan = Pan(numberValue: Number(((Double(value.uintValue) / 127.0) * 2.0) - 1.0)) {
            panMap.insert(time: beatTime,
                          pan: pan)
        }
    }
}

// MARK: - Sendable

extension MIDI.Importer.Context: Sendable {
}
