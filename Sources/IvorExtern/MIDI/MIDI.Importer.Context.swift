// © 2025–2026 John Gary Pusey (see LICENSE.md)

internal import IvorModel
internal import IvorTiming
internal import IvorTuning

private import IvorMIDI
private import IvorSMF
private import XestiNumbers
private import XestiTools

extension MIDI.Importer {

    // MARK: Internal Nested Types

    internal struct Context<TimeMap: MIDI.ImportTimeMap> {

        // MARK: Internal Initializers

        internal init(timeMap: TimeMap) {
            self.timeMap = timeMap
            self.dynamicMap = DynamicMap()
            self.noteTable = NoteTable()
            self.panMap = PanMap()
        }

        // MARK: Internal Instance Properties

        internal var dynamicMap: DynamicMap<TimeMap.TimeType>
        internal var noteTable: NoteTable<TimeMap.TimeType, NoteNumber>
        internal var panMap: PanMap<TimeMap.TimeType>
        internal var timeMap: TimeMap
    }
}

// MARK: -

extension MIDI.Importer.Context {

    // MARK: Internal Instance Methods

    // Inserts a `DynamicMap` entry at the dynamic already active at
    // `eventTime` (an Expression Controller event doesn't itself carry a
    // note-on-velocity-style dynamic — it's a continuous shaper layered on
    // top of whatever's already sounding), tagged with the combined 0-127
    // Expression Controller value. See `expressionValue` in
    // `Extra+DynamicMap.swift`.
    internal mutating func handleExpression(_ eventTime: MIDI.EventTime,
                                            _ value: Int) {
        let time = timeMap.time(at: eventTime)

        dynamicMap.insert(time: time,
                          dynamic: dynamicMap[time],
                          extras: Extras(elements: [Extra(name: Extra.expressionValue.name, values: [.int(value)])]))
    }

    internal mutating func handleNote(_ note: MIDI.Note) {
        let (attack, duration) = timeMap.timeSpan(at: note.startTime,
                                                  ticks: note.duration)

        let extras = note.peakKeyPressure.map {
            Extras(elements: [Extra(name: Extra.midiKeyPressure.name, values: [.int(Int($0.uintValue))])])
        }

        noteTable.insert(attack: attack,
                         duration: duration,
                         pitch: convertToNoteNumber(note.key),
                         extras: extras)

        if let dynamic = convertToDynamic(note.onVelocity) {
            dynamicMap.insert(time: attack,
                              dynamic: dynamic,
                              extras: Extras(elements: [Extra(name: Extra.velocity.name,
                                                              values: [.int(Int(note.onVelocity.uintValue))])]))
        }
    }

    // `panLSB` is the most recently seen Pan LSB (CC 42) value, if any, at
    // this MSB event's tick — combined into a 14-bit `midiPan` extra (see
    // `Extra+PanMap.swift`) alongside the existing 7-bit `Pan` conversion,
    // which stays MSB-only (matching every other format's coarser
    // resolution).
    internal mutating func handlePan(_ eventTime: MIDI.EventTime,
                                     _ panValue: MIDI.PanValue,
                                     _ panLSB: UInt?) {
        let time = timeMap.time(at: eventTime)

        guard let pan = convertToPan(panValue)
        else { return }

        let extras = panLSB.map {
            Extras(elements: [Extra(name: Extra.midiPan.name,
                                    values: [.int(Int((panValue.uintValue << 7) | $0))])])
        }

        panMap.insert(time: time,
                      pan: pan,
                      extras: extras)
    }
}

// MARK: - Sendable

extension MIDI.Importer.Context: Sendable {
}
