// © 2026 John Gary Pusey (see LICENSE.md)

internal import IvorModel
internal import IvorTiming
internal import IvorTuning
internal import XestiTools

extension NoteTable where TimeType == BeatTime, PitchType == Pitch {

    // MARK: Internal Instance Methods

    //
    // Inserts an imported note with its ornamentation. A written partner on the wrong side of
    // its note can't be inserted; the note goes in without its ornament then, rather than not at
    // all.
    //
    @discardableResult
    internal mutating func insertImported(attack: BeatTime,
                                          duration: BeatDuration,
                                          pitch: Pitch,
                                          extras: Extras?,
                                          ornamentation: Ornamentation?) -> NoteID {
        do {
            return try insert(attack: attack,
                              duration: duration,
                              pitch: pitch,
                              extras: extras,
                              ornamentation: ornamentation)
        } catch {
            let kept = Ornamentation(graceBefore: ornamentation?.graceBefore,
                                     graceAfter: ornamentation?.graceAfter,
                                     arpeggio: ornamentation?.arpeggio,
                                     fermata: ornamentation?.fermata)

            return (try? insert(attack: attack,
                                duration: duration,
                                pitch: pitch,
                                extras: extras,
                                ornamentation: kept.isEmpty ? nil : kept))
                ?? insert(attack: attack, duration: duration, pitch: pitch, extras: extras)
        }
    }
}
