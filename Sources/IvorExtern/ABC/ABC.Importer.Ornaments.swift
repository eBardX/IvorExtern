// © 2026 John Gary Pusey (see LICENSE.md)

internal import IvorModel
internal import IvorTiming
internal import IvorTuning
internal import XestiNumbers
internal import XestiTools

// What decorates one ABC note, chord or rest beyond its extras: its grace
// figures, its trill or mordent, its tremolo, its place in a rolled chord, and
// its fermata. The walker stages these for the next event as it reads them,
// moves them onto that event, and turns them into each tone's ornamentation
// when the event goes into the note table (see `ornamentation(isLowest:duration:)`).
extension ABC.Importer {

    // MARK: Internal Nested Types

    internal struct Ornaments {

        // MARK: Internal Instance Properties

        internal var arpeggio: ArpeggioGroup?
        internal var fermata = false
        internal var graceAfter: NoteTable<BeatTime, Pitch>.GraceFigure?
        internal var graceBefore: NoteTable<BeatTime, Pitch>.GraceFigure?
        internal var ornament: NoteTable<BeatTime, Pitch>.Ornament.Sign?
        internal var ornamentSide: PartnerSide = .above
        internal var tremoloMarks: UInt?
        internal var tremoloPartner: [Pitch]?
    }
}

// MARK: -

extension ABC.Importer.Ornaments {

    // MARK: Internal Instance Properties

    internal var isEmpty: Bool {
        arpeggio == nil && !fermata && graceAfter == nil && graceBefore == nil
            && ornament == nil && tremoloMarks == nil
    }

    // MARK: Internal Instance Methods

    //
    // Takes what `later` has that this doesn't: what a tied continuation adds to the note it
    // merges into. This note's own decorations win.
    //
    internal mutating func absorb(_ later: Self) {
        arpeggio = arpeggio ?? later.arpeggio
        fermata = fermata || later.fermata
        graceAfter = graceAfter ?? later.graceAfter
        graceBefore = graceBefore ?? later.graceBefore

        if ornament == nil {
            ornament = later.ornament
            ornamentSide = later.ornamentSide
        }

        if tremoloMarks == nil {
            tremoloMarks = later.tremoloMarks
            tremoloPartner = later.tremoloPartner
        }
    }

    //
    // One tone's ornamentation. A chord's grace figures belong to its lowest tone; its ornament,
    // tremolo, roll and fermata to every tone. A measured tremolo's strokes are its marks plus
    // the flags or beams of the written note (resolution 8 of the grace-notes plan): `duration`
    // is the written value.
    //
    internal func ornamentation(isLowest: Bool,
                                duration: BeatDuration) -> NoteTable<BeatTime, Pitch>.Ornamentation? {
        var ornament: NoteTable<BeatTime, Pitch>.Ornament?

        if let marks = tremoloMarks {
            //
            // Each half of a two-note tremolo is written at half its sounding value.
            //
            let written = tremoloPartner == nil ? duration : duration.divided(by: 2) ?? duration
            let strokes = TremoloStrokes(uintValue: min(8, max(1, marks + convertToFlagCount(written))))
            let partner: NoteTable<BeatTime, Pitch>.Ornament.Partner = tremoloPartner.map { .pitches($0) } ?? .repeat

            ornament = strokes.flatMap { .init(sign: .tremolo(.measured($0)), partner: partner) }
        } else if let sign = self.ornament {
            ornament = .init(sign: sign, partner: .step(ornamentSide, written: nil))
        }

        let ornamentation = NoteTable<BeatTime, Pitch>.Ornamentation(graceBefore: isLowest ? graceBefore : nil,
                                                                     graceAfter: isLowest ? graceAfter : nil,
                                                                     ornament: ornament,
                                                                     arpeggio: arpeggio.map { .init(group: $0) },
                                                                     fermata: fermata ? Fermata() : nil)

        return ornamentation.isEmpty ? nil : ornamentation
    }
}

// MARK: - Sendable

extension ABC.Importer.Ornaments: Sendable {
}
