// © 2026 John Gary Pusey (see LICENSE.md)

internal import IvorModel
internal import IvorTiming
internal import IvorTuning
internal import XestiTools

// One note of a part as a notation exporter lays it out (see
// `ExportSlice`): its start pitch only, since a glissando exports at its
// start pitch, per the module-wide rule. `index` is the note's position
// among its part's tones, which tells apart two tones of the same pitch.
internal struct ExportTone {

    // MARK: Internal Instance Properties

    internal let attack: BeatTime
    internal let duration: BeatDuration
    internal let extras: Extras?
    internal let index: Int
    internal let ornamentation: NoteTable<BeatTime, Pitch>.Ornamentation?
    internal let pitch: Pitch
}

// MARK: -

extension ExportTone {

    // MARK: Internal Type Methods

    // Every note of `noteTable`, in attack order; notes sharing an attack
    // keep the table's own order.
    internal static func tones(of noteTable: NoteTable<BeatTime, Pitch>) -> [Self] {
        let notes = noteTable.enumerated().sorted { ($0.element.attack, $0.offset) < ($1.element.attack, $1.offset) }

        return notes.enumerated().map { index, entry in
            ExportTone(attack: entry.element.attack,
                       duration: entry.element.duration,
                       extras: entry.element.extras,
                       index: index,
                       ornamentation: entry.element.ornamentation,
                       pitch: entry.element.startPitch)
        }
    }

    // MARK: Internal Instance Properties

    internal var end: BeatTime {
        attack + duration
    }
}

// MARK: - Sendable

extension ExportTone: Sendable {
}
