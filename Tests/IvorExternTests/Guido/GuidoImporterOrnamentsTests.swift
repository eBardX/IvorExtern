// © 2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import IvorModel
import IvorTiming
import IvorTuning
import Testing

struct GuidoImporterOrnamentsTests {
}

// MARK: -

extension GuidoImporterOrnamentsTests {
    @Test
    func absorb_figureAfter_isTheLastNotes() throws {
        var ornaments = Guido.Importer.Ornaments()
        var later = Guido.Importer.Ornaments()

        ornaments.graceAfter = try graceFigure("D4")
        later.graceAfter = try graceFigure("E4")

        ornaments.absorb(later)

        #expect(ornaments.graceAfter == later.graceAfter)
    }

    @Test
    func absorb_keepsItsOwnDecorations() throws {
        var ornaments = Guido.Importer.Ornaments()
        var later = Guido.Importer.Ornaments()

        ornaments.fermata = .short
        ornaments.graceBefore = try graceFigure("D4")
        ornaments.isArpeggiated = true
        ornaments.ornamentSign = .trill
        later.fermata = .long
        later.graceBefore = try graceFigure("E4")
        later.isArpeggiated = true
        later.arpeggioDirection = .down
        later.ornamentSign = .mordent
        later.ornamentSide = .below

        let ownGrace = ornaments.graceBefore

        ornaments.absorb(later)

        #expect(ornaments.arpeggioDirection == nil)
        #expect(ornaments.fermata == .short)
        #expect(ornaments.graceBefore == ownGrace)
        #expect(ornaments.ornamentSign == .trill)
        #expect(ornaments.ornamentSide == .above)
    }

    @Test
    func absorb_takesWhatItLacks() throws {
        var ornaments = Guido.Importer.Ornaments()
        var later = Guido.Importer.Ornaments()
        let group = try #require(ArpeggioGroup(uintValue: 3))

        later.arpeggio = group
        later.arpeggioDirection = .up
        later.fermata = .veryLong
        later.graceBefore = try graceFigure("E4")
        later.isArpeggiated = true
        later.ornamentExecution = .init(startNote: .partner)
        later.ornamentSide = .below
        later.ornamentSign = .mordent
        later.writtenPartner = PitchClass(letter: .b, accidental: .flat)

        ornaments.absorb(later)

        #expect(ornaments.arpeggio == group)
        #expect(ornaments.arpeggioDirection == .up)
        #expect(ornaments.fermata == .veryLong)
        #expect(ornaments.graceBefore == later.graceBefore)
        #expect(ornaments.isArpeggiated)
        #expect(ornaments.ornamentExecution == later.ornamentExecution)
        #expect(ornaments.ornamentSide == .below)
        #expect(ornaments.ornamentSign == .mordent)
        #expect(ornaments.writtenPartner == PitchClass(letter: .b, accidental: .flat))
    }

    @Test
    func isEmpty_default() {
        #expect(Guido.Importer.Ornaments().isEmpty)
    }

    @Test
    func isEmpty_eachDecoration() throws {
        var arpeggiated = Guido.Importer.Ornaments()
        var fermata = Guido.Importer.Ornaments()
        var graceAfter = Guido.Importer.Ornaments()
        var graceBefore = Guido.Importer.Ornaments()
        var sign = Guido.Importer.Ornaments()

        arpeggiated.isArpeggiated = true
        fermata.fermata = .normal
        graceAfter.graceAfter = try graceFigure("D4")
        graceBefore.graceBefore = try graceFigure("D4")
        sign.ornamentSign = .trill

        #expect(!arpeggiated.isEmpty)
        #expect(!fermata.isEmpty)
        #expect(!graceAfter.isEmpty)
        #expect(!graceBefore.isEmpty)
        #expect(!sign.isEmpty)
    }

    @Test
    func ornamentation_arpeggio_keepsItsDirection() throws {
        var ornaments = Guido.Importer.Ornaments()
        let group = try #require(ArpeggioGroup(uintValue: 1))

        ornaments.arpeggio = group
        ornaments.arpeggioDirection = .down
        ornaments.isArpeggiated = true

        let arpeggio = ornaments.ornamentation(pitch: "C4", isLowest: false)?.arpeggio

        #expect(arpeggio?.group == group)
        #expect(arpeggio?.direction == .down)
    }

    @Test
    func ornamentation_empty_isNil() {
        #expect(Guido.Importer.Ornaments().ornamentation(pitch: "C4", isLowest: true) == nil)
    }

    @Test
    func ornamentation_fermata_keepsItsShape() {
        var ornaments = Guido.Importer.Ornaments()

        ornaments.fermata = .veryShort

        #expect(ornaments.ornamentation(pitch: "C4", isLowest: false)?.fermata?.shape == .veryShort)
    }

    @Test
    func ornamentation_graces_onlyOnTheLowestTone() throws {
        var ornaments = Guido.Importer.Ornaments()

        ornaments.graceAfter = try graceFigure("E4")
        ornaments.graceBefore = try graceFigure("D4")

        let lowest = ornaments.ornamentation(pitch: "C4", isLowest: true)

        #expect(lowest?.graceAfter == ornaments.graceAfter)
        #expect(lowest?.graceBefore == ornaments.graceBefore)
        #expect(ornaments.ornamentation(pitch: "E4", isLowest: false) == nil)
    }

    @Test
    func ornamentation_sign_keepsItsExecution() {
        var ornaments = Guido.Importer.Ornaments()
        let execution = BeatNotes.OrnamentExecution(startNote: .partner)

        ornaments.ornamentExecution = execution
        ornaments.ornamentSign = .trill

        let ornament = ornaments.ornamentation(pitch: "C4", isLowest: true)?.ornament

        #expect(ornament?.execution == execution)
        #expect(ornament?.partner == .step(.above, written: nil))
    }

    @Test
    func ornamentation_tremolo_partnerPitches() throws {
        var ornaments = Guido.Importer.Ornaments()
        let strokes = try #require(TremoloStrokes(uintValue: 2))

        ornaments.ornamentSign = .tremolo(.measured(strokes))
        ornaments.tremoloPartner = ["E4"]

        #expect(ornaments.ornamentation(pitch: "C4", isLowest: true)?.ornament?.partner == .pitches(["E4"]))
    }

    @Test
    func ornamentation_tremolo_repeatsWithNoPartner() throws {
        var ornaments = Guido.Importer.Ornaments()
        let strokes = try #require(TremoloStrokes(uintValue: 2))

        ornaments.ornamentSign = .tremolo(.measured(strokes))

        #expect(ornaments.ornamentation(pitch: "C4", isLowest: true)?.ornament?.partner == .repeat)
    }

    @Test
    func ornamentation_writtenPartner_takesTheNearestOctaveAbove() {
        var ornaments = Guido.Importer.Ornaments()

        ornaments.ornamentSign = .trill
        ornaments.writtenPartner = PitchClass(letter: .a, accidental: .natural)

        #expect(ornaments.ornamentation(pitch: "B4", isLowest: true)?.ornament?.partner == .step(.above, written: "A5"))
    }

    @Test
    func ornamentation_writtenPartner_takesTheNearestOctaveBelow() {
        var ornaments = Guido.Importer.Ornaments()

        ornaments.ornamentSide = .below
        ornaments.ornamentSign = .mordent
        ornaments.writtenPartner = PitchClass(letter: .d, accidental: .natural)

        #expect(ornaments.ornamentation(pitch: "C4", isLowest: true)?.ornament?.partner == .step(.below, written: "D3"))
    }
}
