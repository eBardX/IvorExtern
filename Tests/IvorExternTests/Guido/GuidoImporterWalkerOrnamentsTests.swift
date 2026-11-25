// © 2026 John Gary Pusey (see LICENSE.md)

import Foundation
@testable import IvorExtern
import IvorModel
import IvorTiming
import IvorTuning
import Testing
import XestiNumbers

// Reading Guido's grace notes, trills, mordents, tremolos, rolls and fermatas into
// ornamentation.
struct GuidoImporterWalkerOrnamentsTests {
}

// MARK: -

extension GuidoImporterWalkerOrnamentsTests {
    @Test
    func arpeggio_eachRollGetsItsOwnGroupAcrossVoices() throws {
        let work = try readGuido(#"""
            { [ \arpeggio<direction="down">({c1/4, e, g}) \arpeggio({c, e}) ],
              [ \arpeggio({c0/2, e}) ] }
            """#)
        let parts = try #require(standardBeatParts(of: work))
        let groups = parts.map { $0.noteTable.map { $0.ornamentation?.arpeggio?.group.uintValue } }
        let directions = parts[0].noteTable.map { $0.ornamentation?.arpeggio?.direction }

        #expect(groups[0] == [1, 1, 1, 2, 2])
        #expect(groups[1] == [3, 3])
        #expect(directions == [.down, .down, .down, nil, nil])
    }

    @Test
    func fermata_bodilessAtTheStart_waitsForTheRestAfterIt() throws {
        let part = try guidoPart(#"[ \fermata _/4 c1/4 ]"#)

        #expect(part.noteTable.first?.ornamentation == nil)
        #expect(part.markTable.map(\.time) == [.zero])
    }

    @Test
    func fermata_bodilessBetweenNotes_marksTheNoteBefore() throws {
        let part = try guidoPart(#"[ c1/4 \fermata d e ]"#)

        #expect(part.noteTable.allSatisfy { $0.ornamentation?.fermata == nil })
        #expect(part.markTable.map(\.time) == [.zero])
        #expect(try part.markTable.map(\.mark) == [.fermata(Fermata(), span: #require(PositiveDuration(dur(1, 4))))])
    }

    @Test
    func fermata_onEveryNoteOfItsRange_withItsShape() throws {
        let notes = try guidoNotes(#"[ \fermata<type="short">(c1/4) \fermata<type="long">(d) \fermata(e f) g ]"#)

        #expect(notes.map { $0.ornamentation?.fermata?.shape } == [.short, .long, .normal, .normal, nil])
    }

    @Test
    func grace_beforeABarLine_gracesTheNextNote() throws {
        let notes = try guidoNotes(#"[ \meter<"1/4"> c1/4 \grace(d/16) \bar e/4 ]"#)

        #expect(notes.map { $0.ornamentation?.graceBefore?.pitches } == [nil, [.d4]])
        #expect(notes.map { $0.ornamentation?.graceAfter } == [nil, nil])
    }

    @Test
    func grace_beforeARest_followsTheNoteBefore() throws {
        let notes = try guidoNotes(#"[ c1/4 \grace(d/16) _/4 e/4 ]"#)

        #expect(notes.map { $0.ornamentation?.graceAfter?.pitches } == [[.d4], nil])
        #expect(notes.map { $0.ornamentation?.graceBefore } == [nil, nil])
    }

    @Test
    func grace_body_becomesAFigureOfItsNotesAndChords() throws {
        let notes = try guidoNotes(#"[ \grace(d1/16 {e/32, g}) c1/4 ]"#)
        let figure = try #require(notes.first?.ornamentation?.graceBefore)

        #expect(notes.map(\.attack) == [.zero])
        #expect(figure.events.map(\.pitches) == [[.d4], [.e4, .g4]])
        #expect(figure.events.map { $0.length?.duration } == [dur(1, 16), dur(1, 32)])
        #expect(!figure.isSlashed)
        #expect(!figure.isTiedToMainNote)
    }

    @Test
    func grace_nested_isFlattenedAndItsIndexIgnored() throws {
        let notes = try guidoNotes(#"[ \grace<i=2>(d1/16 \grace(e)) c1/4 ]"#)

        #expect(notes.first?.ornamentation?.graceBefore?.events.map(\.pitches) == [[.d4], [.e4]])
    }

    @Test
    func grace_onAChord_belongsToItsLowestTone() throws {
        let notes = try guidoNotes(#"[ \grace(d1/16) {g1/4, c, e} ]"#)

        let figures = Dictionary(uniqueKeysWithValues: notes.map { ($0.startPitch, $0.ornamentation?.graceBefore?.pitches) })

        #expect(figures == [.c4: [.d4], .e4: nil, .g4: nil])
    }

    @Test
    func grace_tieAfterItsLastNote_tiesIntoTheMainNote() throws {
        let notes = try guidoNotes(#"[ \grace(c1/16 \tieEnd) c/4 ]"#)

        #expect(notes.first?.ornamentation?.graceBefore?.isTiedToMainNote == true)
    }

    @Test
    func mordent_types_giveTheSideAndCount() throws {
        let notes = try guidoNotes(#"""
            [ \mordent(c1/4) \mordent<type="inverted">(d) \mordent<type="prallprall">(e) \mordent<type="prallinverted">(f) ]
            """#)
        let double = try #require(AlternationCount(uintValue: 2))

        #expect(notes.map { $0.ornamentation?.ornament?.sign } == Array(repeating: .mordent, count: 4))
        #expect(notes.map { $0.ornamentation?.ornament?.partner } == [.step(.above, written: nil),
                                                                      .step(.below, written: nil),
                                                                      .step(.above, written: nil),
                                                                      .step(.below, written: nil)])
        #expect(notes.map { $0.ornamentation?.ornament?.execution?.extent } == [nil, nil, .count(double), .count(double)])
    }

    @Test
    func tremolo_pitch_isATwoNoteTremoloOfTwiceTheWrittenLength() throws {
        let notes = try guidoNotes(#"[ \tremolo<pitch="g", speed=16>(c1/4) e/4 ]"#)
        let strokes = try #require(TremoloStrokes(uintValue: 2))

        #expect(notes.map(\.attack) == [.zero, beat(1, 2)])
        #expect(notes.map(\.duration) == [dur(1, 2), dur(1, 4)])
        #expect(notes.first?.ornamentation?.ornament?.sign == .tremolo(.measured(strokes)))
        #expect(notes.first?.ornamentation?.ornament?.partner == .pitches([.g4]))
    }

    @Test(arguments: [(#"\tremolo<style="//">(c1/8)"#, UInt(3)),
                      (#"\tremolo(c1/4)"#, 3),
                      (#"\tremolo<speed=64>(c1/4)"#, 4),
                      (#"\tremolo<style="/", speed=12>(c1/16)"#, 3)])
    func tremolo_strokes_fromSpeedElseStyleAndFlags(_ tag: String,
                                                    _ expected: UInt) throws {
        let notes = try guidoNotes("[ \(tag) ]")
        let strokes = try #require(TremoloStrokes(uintValue: expected))

        #expect(notes.first?.ornamentation?.ornament?.sign == .tremolo(.measured(strokes)))
        #expect(notes.first?.ornamentation?.ornament?.partner == .repeat)
    }

    @Test
    func trill_detune_ofAQuarterToneDropsTheWrittenPartner() throws {
        let warnings = WarningCollector()
        let file = FileWrapper(regularFileWithContents: Data(#"[ \trill<note="b", detune=0.5>(a1/4) ]"#.utf8))
        let work = try #require(Guido.Importer().read(from: file, as: .gmn, warnings: warnings).first)
        let notes = try #require(standardBeatParts(of: work)?.first).noteTable

        #expect(notes.first?.ornamentation?.ornament?.partner == .step(.above, written: nil))
        #expect(warnings.warnings == [ExternWarning(kind: .droppedExecution, count: 1, workIndex: 0)])
    }

    @Test
    func trill_detune_ofWholeHalfStepsMovesTheAccidental() throws {
        let notes = try guidoNotes(#"[ \trill<note="b", detune=-1.0>(a1/4) ]"#)

        #expect(notes.first?.ornamentation?.ornament?.partner == .step(.above, written: .bFlat4))
    }

    @Test
    func trill_dur_isItsRate() throws {
        let notes = try guidoNotes(#"[ \trill<dur=16>(c1/4) ]"#)
        let sixteenth = try #require(PositiveDuration(dur(1, 16)))

        #expect(notes.first?.ornamentation?.ornament?.execution == .init(rate: .noteValue(sixteenth)))
    }

    @Test
    func trill_note_isTheWrittenPartnerNearestAbove() throws {
        let notes = try guidoNotes(#"[ \trill<note="b&">(a1/4) \trill<note="c">(b) ]"#)

        #expect(notes.map { $0.ornamentation?.ornament?.partner } == [.step(.above, written: .bFlat4),
                                                                      .step(.above, written: .c5)])
    }

    @Test
    func trill_range_coversEachNote_andASpanUntilItsEnd() throws {
        let notes = try guidoNotes(#"[ \trill(c1/4 d) \trillBegin e f \trillEnd g ]"#)

        #expect(notes.map { $0.ornamentation?.ornament?.sign } == [.trill, .trill, .trill, .trill, nil])
    }

    @Test
    func trill_tiedNote_keepsOneTrill() throws {
        let notes = try guidoNotes(#"[ \trill(c1/4) \tieEnd c/4 d ]"#)

        #expect(notes.map(\.duration) == [dur(1, 2), dur(1, 4)])
        #expect(notes.map { $0.ornamentation?.ornament?.sign } == [.trill, nil])
    }
}
