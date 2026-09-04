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

        // MARK: Internal Initializers

        internal init(beatMap: MIDI.BeatMap) {
            self.beatMap = beatMap
            self.dynamicMap = DynamicMap()
            self.noteTable = NoteTable()
            self.panMap = PanMap()
        }

        // MARK: Internal Instance Properties

        internal var beatMap: MIDI.BeatMap
        internal var dynamicMap: DynamicMap<BeatTime>
        internal var noteTable: NoteTable<BeatTime, NoteNumber>
        internal var panMap: PanMap<BeatTime>
    }
}

// MARK: -

extension MIDI.Importer.Context {

    // MARK: Internal Instance Methods

    internal mutating func handleNote(_ note: MIDI.Note) {
        let (attack, _) = beatMap[note.startTime]
        let (release, _) = beatMap[MIDI.EventTime(note.startTime.uintValue + note.duration)]

        noteTable.insert(attack: attack,
                         duration: release - attack,
                         pitch: convertToNoteNumber(note.key))

        if let dynamic = convertToDynamic(note.onVelocity) {
            dynamicMap.insert(time: attack,
                              dynamic: dynamic)
        }
    }

    internal mutating func handlePan(_ eventTime: MIDI.EventTime,
                                     _ panValue: MIDI.PanValue) {
        let (beatTime, _) = beatMap[eventTime]

        if let pan = convertToPan(panValue) {
            panMap.insert(time: beatTime,
                          pan: pan)
        }
    }
}

// MARK: - Sendable

extension MIDI.Importer.Context: Sendable {
}
