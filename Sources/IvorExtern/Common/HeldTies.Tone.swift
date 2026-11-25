// © 2026 John Gary Pusey (see LICENSE.md)

internal import IvorModel
internal import IvorTiming
internal import IvorTuning
internal import XestiTools

extension HeldTies {

    // MARK: Internal Nested Types

    // One tone of a note or chord an importer has read, and whether it is
    // tied to whatever follows (see `HeldTies.commit(_:into:)`).
    internal struct Tone {

        // MARK: Internal Initializers

        internal init(attack: BeatTime,
                      duration: BeatDuration,
                      extras: Extras?,
                      isTied: Bool,
                      ornamentation: NoteTable<BeatTime, Pitch>.Ornamentation? = nil,
                      pitch: Pitch) {
            self.attack = attack
            self.duration = duration
            self.extras = extras
            self.isTied = isTied
            self.pitch = pitch
            self.ornamentation = ornamentation
        }

        // MARK: Internal Instance Properties

        internal let attack: BeatTime
        internal let duration: BeatDuration
        internal let extras: Extras?
        internal let isTied: Bool
        internal let pitch: Pitch
        internal var ornamentation: NoteTable<BeatTime, Pitch>.Ornamentation?
    }
}

// MARK: -

extension HeldTies.Tone {

    // MARK: Internal Instance Methods

    internal func insert(into noteTable: inout NoteTable<BeatTime, Pitch>) {
        noteTable.insertImported(attack: attack,
                                 duration: duration,
                                 pitch: pitch,
                                 extras: extras,
                                 ornamentation: ornamentation)
    }
}

// MARK: - Sendable

extension HeldTies.Tone: Sendable {
}
