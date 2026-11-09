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
            self.pedals = [:]
        }

        // MARK: Internal Instance Properties

        internal var dynamicMap: DynamicMap<TimeMap.TimeType>
        internal var noteTable: NoteTable<TimeMap.TimeType, NoteNumber>
        internal var panMap: PanMap<TimeMap.TimeType>
        internal var pedals: [Pedal: PedalTable<TimeMap.TimeType>]
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

    // The note-on velocity is kept exactly on the note itself, as
    // `attackVelocity`, so it travels with the note through every transform; the
    // dynamic map gets the level it implies, for everything that reads
    // dynamics. That level is a step, not the end of a ramp from the note
    // before, so the level in effect is reasserted first; an unchanged
    // level collapses into one entry. Notes must come in time order. A
    // note-off velocity of 0 (often a zero-velocity note-on
    // standing in for the note-off) or 64 (what MIDI prescribes for a
    // device that doesn't sense release velocity) says nothing about the
    // note, so only another value is kept, as `releaseVelocity`.
    internal mutating func handleNote(_ note: MIDI.Note) {
        let (attack, duration) = timeMap.timeSpan(at: note.startTime,
                                                  ticks: note.duration)

        var elements = [Extra(name: Extra.attackVelocity.name, values: [.int(Int(note.onVelocity.uintValue))])]

        if let pressure = note.peakKeyPressure {
            elements.append(Extra(name: Extra.midiKeyPressure.name, values: [.int(Int(pressure.uintValue))]))
        }

        if ![0, 64].contains(note.offVelocity.uintValue) {
            elements.append(Extra(name: Extra.releaseVelocity.name, values: [.int(Int(note.offVelocity.uintValue))]))
        }

        noteTable.insert(attack: attack,
                         duration: duration,
                         pitch: convertToNoteNumber(note.key),
                         extras: Extras(elements: elements))

        if let dynamic = convertToDynamic(note.onVelocity) {
            if !dynamicMap.isEmpty {
                dynamicMap.insert(time: attack,
                                  dynamic: dynamicMap[attack])
            }

            dynamicMap.insert(time: attack,
                              dynamic: dynamic)
        }
    }

    // `panLSB` is the most recently seen Pan LSB (CC 42) value, if any, at
    // this MSB event's tick — combined into a 14-bit `midiPan` extra (see
    // `Extra+PanMap.swift`) alongside the existing 7-bit `Pan` conversion,
    // which stays MSB-only (matching every other format's coarser
    // resolution). A Pan event is a step, not the end of a glide from the
    // one before, so the pan in effect is reasserted first; events must
    // come in time order.
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

        if !panMap.isEmpty {
            panMap.insert(time: time,
                          pan: panMap[time])
        }

        panMap.insert(time: time,
                      pan: pan,
                      extras: extras)
    }

    // Every pedal event becomes an entry, repeats included, so the stream
    // round-trips (only an identical event at the same tick folds, per
    // `PedalTable`'s rule). The value is kept exactly — no snapping — so
    // half-pedaling survives. Events must come in file order.
    internal mutating func handlePedal(_ eventTime: MIDI.EventTime,
                                       _ pedal: Pedal,
                                       _ value: MIDI.PedalValue) {
        pedals[pedal, default: PedalTable()].insert(time: timeMap.time(at: eventTime),
                                                    level: convertToPedalLevel(midiValue: value))
    }
}

// MARK: - Sendable

extension MIDI.Importer.Context: Sendable {
}
