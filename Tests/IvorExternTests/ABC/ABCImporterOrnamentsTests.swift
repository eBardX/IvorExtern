// © 2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import IvorModel
import IvorTiming
import IvorTuning
import Testing

struct ABCImporterOrnamentsTests {
}

// MARK: -

extension ABCImporterOrnamentsTests {
    @Test
    func absorb_keepsItsOwnDecorations() {
        var ornaments = ABC.Importer.Ornaments()
        var later = ABC.Importer.Ornaments()

        ornaments.ornament = .trill
        ornaments.ornamentSide = .above
        later.ornament = .mordent
        later.ornamentSide = .below
        later.tremoloMarks = 2

        ornaments.absorb(later)

        #expect(ornaments.ornament == .trill)
        #expect(ornaments.ornamentSide == .above)
        #expect(ornaments.tremoloMarks == 2)
    }

    @Test
    func absorb_takesWhatItLacks() throws {
        var ornaments = ABC.Importer.Ornaments()
        var later = ABC.Importer.Ornaments()
        let group = try #require(ArpeggioGroup(uintValue: 1))

        later.arpeggio = group
        later.fermata = true
        later.graceAfter = try graceFigure("D4")
        later.graceBefore = try graceFigure("E4")
        later.ornament = .mordent
        later.ornamentSide = .below
        later.tremoloMarks = 1
        later.tremoloPartner = ["G4"]

        ornaments.absorb(later)

        #expect(ornaments.arpeggio == group)
        #expect(ornaments.fermata)
        #expect(ornaments.graceAfter == later.graceAfter)
        #expect(ornaments.graceBefore == later.graceBefore)
        #expect(ornaments.ornament == .mordent)
        #expect(ornaments.ornamentSide == .below)
        #expect(ornaments.tremoloMarks == 1)
        #expect(ornaments.tremoloPartner == ["G4"])
    }

    @Test
    func isEmpty_default() {
        #expect(ABC.Importer.Ornaments().isEmpty)
    }

    @Test
    func isEmpty_eachDecoration() throws {
        var arpeggio = ABC.Importer.Ornaments()
        var fermata = ABC.Importer.Ornaments()
        var graceAfter = ABC.Importer.Ornaments()
        var graceBefore = ABC.Importer.Ornaments()
        var ornament = ABC.Importer.Ornaments()
        var tremolo = ABC.Importer.Ornaments()

        arpeggio.arpeggio = try #require(ArpeggioGroup(uintValue: 1))
        fermata.fermata = true
        graceAfter.graceAfter = try graceFigure("D4")
        graceBefore.graceBefore = try graceFigure("D4")
        ornament.ornament = .trill
        tremolo.tremoloMarks = 1

        #expect(!arpeggio.isEmpty)
        #expect(!fermata.isEmpty)
        #expect(!graceAfter.isEmpty)
        #expect(!graceBefore.isEmpty)
        #expect(!ornament.isEmpty)
        #expect(!tremolo.isEmpty)
    }

    @Test
    func isEmpty_sideOrPartnerAlone() {
        var ornaments = ABC.Importer.Ornaments()

        ornaments.ornamentSide = .below
        ornaments.tremoloPartner = ["C4"]

        #expect(ornaments.isEmpty)
    }

    @Test
    func ornamentation_empty_isNil() {
        #expect(ABC.Importer.Ornaments().ornamentation(isLowest: true, duration: dur(1, 4)) == nil)
    }

    @Test
    func ornamentation_fermataAndArpeggio_onEveryTone() throws {
        var ornaments = ABC.Importer.Ornaments()
        let group = try #require(ArpeggioGroup(uintValue: 2))

        ornaments.arpeggio = group
        ornaments.fermata = true

        let ornamentation = ornaments.ornamentation(isLowest: false, duration: dur(1, 4))

        #expect(ornamentation?.arpeggio?.group == group)
        #expect(ornamentation?.fermata != nil)
    }

    @Test
    func ornamentation_graces_onlyOnTheLowestTone() throws {
        var ornaments = ABC.Importer.Ornaments()

        ornaments.graceBefore = try graceFigure("D4")
        ornaments.graceAfter = try graceFigure("E4")

        let lowest = ornaments.ornamentation(isLowest: true, duration: dur(1, 4))

        #expect(lowest?.graceBefore == ornaments.graceBefore)
        #expect(lowest?.graceAfter == ornaments.graceAfter)
        #expect(ornaments.ornamentation(isLowest: false, duration: dur(1, 4)) == nil)
    }

    @Test
    func ornamentation_sign_stepsToItsSide() {
        var ornaments = ABC.Importer.Ornaments()

        ornaments.ornament = .mordent
        ornaments.ornamentSide = .below

        let ornament = ornaments.ornamentation(isLowest: false, duration: dur(1, 4))?.ornament

        #expect(ornament?.sign == .mordent)
        #expect(ornament?.partner == .step(.below, written: nil))
    }

    @Test
    func ornamentation_tremolo_addsTheNotesFlags() throws {
        var ornaments = ABC.Importer.Ornaments()

        ornaments.tremoloMarks = 1

        let ornament = ornaments.ornamentation(isLowest: true, duration: dur(1, 8))?.ornament
        let strokes = try #require(TremoloStrokes(uintValue: 2))

        #expect(ornament?.sign == .tremolo(.measured(strokes)))
        #expect(ornament?.partner == .repeat)
    }

    @Test
    func ornamentation_tremolo_capsAtEightStrokes() throws {
        var ornaments = ABC.Importer.Ornaments()

        ornaments.tremoloMarks = 7

        let ornament = ornaments.ornamentation(isLowest: true, duration: dur(1, 16))?.ornament
        let strokes = try #require(TremoloStrokes(uintValue: 8))

        #expect(ornament?.sign == .tremolo(.measured(strokes)))
    }

    @Test
    func ornamentation_tremoloWins_overASign() throws {
        var ornaments = ABC.Importer.Ornaments()

        ornaments.ornament = .trill
        ornaments.tremoloMarks = 3

        let strokes = try #require(TremoloStrokes(uintValue: 3))

        #expect(ornaments.ornamentation(isLowest: true, duration: dur(1, 4))?.ornament?.sign == .tremolo(.measured(strokes)))
    }

    @Test
    func ornamentation_twoNoteTremolo_halvesTheWrittenValue() throws {
        var ornaments = ABC.Importer.Ornaments()

        ornaments.tremoloMarks = 1
        ornaments.tremoloPartner = ["E4"]

        let ornament = ornaments.ornamentation(isLowest: true, duration: dur(1, 4))?.ornament
        let strokes = try #require(TremoloStrokes(uintValue: 2))

        #expect(ornament?.sign == .tremolo(.measured(strokes)))
        #expect(ornament?.partner == .pitches(["E4"]))
    }
}
