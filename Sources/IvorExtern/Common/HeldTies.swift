// © 2026 John Gary Pusey (see LICENSE.md)

internal import IvorModel
internal import IvorTiming
internal import IvorTuning

// The tones an importer has read that are tied to whatever follows, not yet
// in the note table, for formats that tie each tone on its own: ABC's
// `[C-E] [CG]` and Guido's `{ \tieBegin:1 c, e } { c \tieEnd:1, g }` tie
// only the C. The next note or chord continues each one with a tone of the
// same pitch; a tie it doesn't continue ends where it was written.
internal struct HeldTies {

    // MARK: Private Instance Properties

    private var tones: [Tone] = []
}

// MARK: -

extension HeldTies {

    // MARK: Internal Instance Methods

    // Commits the tones of one note or chord, in order. Each continues the
    // held tie of its pitch, if there is one, taking its attack and extras,
    // and the ornamentation a tied note keeps (see
    // `NoteTable.Ornamentation.merged(first:last:)`).
    // A tone tied to whatever follows is held in turn; any other goes into
    // `noteTable`. Every tie the note or chord doesn't continue ends.
    internal mutating func commit(_ newTones: [Tone],
                                  into noteTable: inout NoteTable<BeatTime, Pitch>) {
        var heldTones: [Tone] = []

        for newTone in newTones {
            var tone = newTone

            if let index = tones.firstIndex(where: { $0.pitch == newTone.pitch }) {
                let earlier = tones.remove(at: index)

                tone = Tone(attack: earlier.attack,
                            duration: earlier.duration + newTone.duration,
                            extras: earlier.extras,
                            isTied: newTone.isTied,
                            ornamentation: .merged(first: earlier.ornamentation,
                                                   last: newTone.ornamentation),
                            pitch: newTone.pitch)
            }

            if tone.isTied {
                heldTones.append(tone)
            } else {
                tone.insert(into: &noteTable)
            }
        }

        end(in: &noteTable)

        tones = heldTones
    }

    // Ends every held tie where it was written.
    internal mutating func end(in noteTable: inout NoteTable<BeatTime, Pitch>) {
        for tone in tones {
            tone.insert(into: &noteTable)
        }

        tones = []
    }
}

// MARK: - Sendable

extension HeldTies: Sendable {
}
