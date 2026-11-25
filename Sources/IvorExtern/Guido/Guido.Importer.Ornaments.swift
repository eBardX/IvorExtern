// © 2026 John Gary Pusey (see LICENSE.md)

internal import IvorModel
internal import IvorTiming
internal import IvorTuning

// What decorates one Guido note or chord beyond its extras: its grace figures, its trill,
// mordent or tremolo, its place in a rolled chord, and its fermata. The walker builds one from
// the ornament tags in force when the note or chord is read (see
// `Guido.Importer.Walker.takeOrnaments(_:_:)`), keeps it with the pending note, and turns it
// into each tone's ornamentation when the note goes into the note table (see
// `ornamentation(pitch:isLowest:)`).
extension Guido.Importer {

    // MARK: Internal Nested Types

    internal struct Ornaments {

        // MARK: Internal Instance Properties

        internal var arpeggio: ArpeggioGroup?
        internal var arpeggioDirection: ArpeggioDirection?
        internal var fermata: FermataShape?
        internal var graceAfter: NoteTable<BeatTime, Pitch>.GraceFigure?
        internal var graceBefore: NoteTable<BeatTime, Pitch>.GraceFigure?
        internal var isArpeggiated = false
        internal var ornamentExecution: NoteTable<BeatTime, Pitch>.OrnamentExecution?
        internal var ornamentSide: PartnerSide = .above
        internal var ornamentSign: NoteTable<BeatTime, Pitch>.Ornament.Sign?
        internal var tremoloPartner: [Pitch]?
        internal var writtenPartner: PitchClass?
    }
}

// MARK: -

extension Guido.Importer.Ornaments {

    // MARK: Internal Instance Properties

    internal var isEmpty: Bool {
        !isArpeggiated && fermata == nil && graceAfter == nil && graceBefore == nil && ornamentSign == nil
    }

    // MARK: Internal Instance Methods

    //
    // Takes what `later` has that this doesn't: what a tied continuation adds to the note it
    // merges into. This note's own decorations win, except the figure after, which is the last
    // note's (see `NoteTable.Ornamentation.merged(first:last:)`).
    //
    internal mutating func absorb(_ later: Self) {
        if !isArpeggiated {
            arpeggio = later.arpeggio
            arpeggioDirection = later.arpeggioDirection
            isArpeggiated = later.isArpeggiated
        }

        fermata = fermata ?? later.fermata
        graceAfter = later.graceAfter ?? graceAfter
        graceBefore = graceBefore ?? later.graceBefore

        if ornamentSign == nil {
            ornamentExecution = later.ornamentExecution
            ornamentSide = later.ornamentSide
            ornamentSign = later.ornamentSign
            tremoloPartner = later.tremoloPartner
            writtenPartner = later.writtenPartner
        }
    }

    //
    // One tone's ornamentation. A chord's grace figures belong to its lowest tone; its ornament,
    // roll and fermata to every tone. A written partner (`\trill<note=…>`) is a pitch class: it
    // takes the octave that puts it nearest the tone on its side, and is dropped if it can't be
    // on that side.
    //
    internal func ornamentation(pitch: Pitch,
                                isLowest: Bool) -> NoteTable<BeatTime, Pitch>.Ornamentation? {
        var ornament: NoteTable<BeatTime, Pitch>.Ornament?

        if let sign = ornamentSign {
            if case .tremolo = sign {
                ornament = .init(sign: sign,
                                 partner: tremoloPartner.map { .pitches($0) } ?? .repeat,
                                 execution: ornamentExecution)
            } else {
                let written = writtenPartner.flatMap { Self._nearestPitch($0, side: ornamentSide, of: pitch) }

                ornament = .init(sign: sign,
                                 partner: .step(ornamentSide, written: written),
                                 execution: ornamentExecution)
            }
        }

        let ornamentation = NoteTable<BeatTime, Pitch>.Ornamentation(graceBefore: isLowest ? graceBefore : nil,
                                                                     graceAfter: isLowest ? graceAfter : nil,
                                                                     ornament: ornament,
                                                                     arpeggio: arpeggio.map { .init(group: $0, direction: arpeggioDirection) },
                                                                     fermata: fermata.map { Fermata(shape: $0) })

        return ornamentation.isEmpty ? nil : ornamentation
    }

    // MARK: Private Type Methods

    private static func _nearestPitch(_ pitchClass: PitchClass,
                                      side: PartnerSide,
                                      of pitch: Pitch) -> Pitch? {
        let candidates = (-1...1).compactMap { offset in
            Pitch.Octave(intValue: pitch.octave.intValue + offset).map { Pitch(pitchClass: pitchClass, octave: $0) }
        }

        switch side {
        case .above:
            return candidates.filter { $0 > pitch }.min()

        case .below:
            return candidates.filter { $0 < pitch }.max()
        }
    }
}

// MARK: - Sendable

extension Guido.Importer.Ornaments: Sendable {
}
