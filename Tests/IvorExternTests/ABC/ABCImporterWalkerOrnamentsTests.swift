// © 2026 John Gary Pusey (see LICENSE.md)

import Foundation
@testable import IvorExtern
import IvorModel
import IvorTiming
import IvorTuning
import Testing
import XestiNumbers

// Reading ABC's grace groups, trills, mordents, rolls, tremolos and fermatas into
// ornamentation.
struct ABCImporterWalkerOrnamentsTests {
}

// MARK: -

extension ABCImporterWalkerOrnamentsTests {
    @Test
    func arpeggio_eachRollGetsItsOwnGroupAcrossVoices() throws {
        let work = try readABC("""
            X:1
            T:Rolls
            L:1/4
            K:C
            V:1
            !arpeggio![CEG] !arpeggio![CE]|
            V:2
            !arpeggio![C,E,]|
            """)
        let parts = try #require(standardBeatParts(of: work))
        let groups = parts.map { $0.noteTable.map { $0.ornamentation?.arpeggio?.group.uintValue } }

        #expect(groups[0] == [1, 1, 1, 2, 2])
        #expect(groups[1] == [3, 3])
    }

    @Test
    func fermata_onANoteAChordAndARest() throws {
        let context = try abcContext("""
            X:1
            L:1/4
            K:C
            !fermata!C H[EG] !invertedfermata!D !fermata!z|
            """)
        let notes = Array(context.noteTable)

        #expect(notes.map { $0.ornamentation?.fermata } == Array(repeating: Fermata(), count: 4))
        #expect(context.markTable.map(\.time) == [beatTime(frac(3, 4))])
        #expect(context.markTable.first?.mark == .fermata(Fermata(), span: PositiveDuration(beats(frac(1, 4))).unsafelyUnwrapped))
    }

    @Test
    func grace_atTheStartBeforeARestGracesTheNextNote() throws {
        let notes = try abcNotes("""
            X:1
            L:1/4
            K:C
            {D}z C|
            """)

        #expect(notes.first?.ornamentation?.graceBefore?.pitches == [.d4])
    }

    @Test
    func grace_beforeARestOrBarLineFollowsThePreviousNote() throws {
        let notes = try abcNotes("""
            X:1
            L:1/4
            M:2/4
            K:C
            C {D}z E {F}|G2|
            """)

        #expect(notes.map { $0.ornamentation?.graceAfter?.pitches } == [[.d4], [.f4], nil])
        #expect(notes.allSatisfy { $0.ornamentation?.graceBefore == nil })
    }

    @Test
    func grace_betweenTiedNotesBreaksTheTie() throws {
        let notes = try abcNotes("""
            X:1
            L:1/4
            K:C
            C-{D}C|
            """)

        #expect(notes.map(\.attack) == [0, beatTime(frac(1, 4))])
        #expect(notes.last?.ornamentation?.graceBefore?.pitches == [.d4])
    }

    @Test
    func grace_chordInBracesAndOnAChord() throws {
        let notes = try abcNotes("""
            X:1
            L:1/4
            K:C
            {[DF]E}[CEG]|
            """)
        let figure = try #require(notes.first { $0.startPitch == .c4 }?.ornamentation?.graceBefore)

        #expect(figure.events.map(\.pitches) == [[.d4, .f4], [.e4]])
        #expect(notes.filter { $0.ornamentation?.graceBefore != nil }.count == 1)
    }

    @Test
    func grace_unitLengthsSlashAndTie() throws {
        let notes = try abcNotes("""
            X:1
            L:1/2
            K:C
            {D}C {/DE}C {D2E}C {C-}C|
            """)
        let figures = notes.compactMap(\.ornamentation?.graceBefore)

        //
        // A lone grace note is an eighth; each of a group a sixteenth; written lengths multiply.
        //
        #expect(figures.map { $0.events.map { $0.length?.duration } } == [[beats(frac(1, 8))],
                                                                          [beats(frac(1, 16)), beats(frac(1, 16))],
                                                                          [beats(frac(1, 8)), beats(frac(1, 16))],
                                                                          [beats(frac(1, 8))]])
        #expect(figures.map(\.isSlashed) == [false, true, false, false])
        #expect(figures.map(\.isTiedToMainNote) == [false, false, false, true])
    }

    @Test
    func mordents_keepTheirSide() throws {
        let notes = try abcNotes("""
            X:1
            L:1/4
            K:C
            !uppermordent!C PC !pralltriller!C !lowermordent!C MC !mordent!C|
            """)
        let sides = notes.map { note -> PartnerSide? in
            guard case let .step(side, _)? = note.ornamentation?.ornament?.partner
            else { return nil }

            return side
        }

        #expect(notes.allSatisfy { $0.ornamentation?.ornament?.sign == .mordent })
        #expect(sides == [.above, .above, .above, .below, .below, .below])
    }

    @Test
    func tremolo_singleAddsTheWrittenNotesFlags() throws {
        let notes = try abcNotes("""
            X:1
            L:1/4
            K:C
            !//!C [L:1/8] !/!D|
            """)

        #expect(notes.map(\.ornamentation?.ornament?.sign) == [.tremolo(.measured(TremoloStrokes(uintValue: 2).unsafelyUnwrapped)),
                                                               .tremolo(.measured(TremoloStrokes(uintValue: 2).unsafelyUnwrapped))])
        #expect(notes.allSatisfy { $0.ornamentation?.ornament?.partner == .repeat })
    }

    @Test
    func tremolo_twoNoteJoinsTheHalves() throws {
        let notes = try abcNotes("""
            X:1
            L:1/8
            K:C
            C2!trem2!E2 G|
            """)
        let ornament = try #require(notes.first?.ornamentation?.ornament)

        //
        // Each half is written as a quarter of a half note's tremolo: one note, as long as the two.
        //
        #expect(notes.map(\.startPitch) == [.c4, .g4])
        #expect(notes.first?.duration == beats(frac(1, 2)))
        #expect(ornament.sign == .tremolo(.measured(TremoloStrokes(uintValue: 2).unsafelyUnwrapped)))
        #expect(ornament.partner == .pitches([.e4]))
        #expect(notes.last?.attack == beatTime(frac(1, 2)))
    }

    @Test
    func trill_markAndExtendedTrillOverTiedNotes() throws {
        let notes = try abcNotes("""
            X:1
            L:1/4
            K:C
            TC !trill(!D-D!trill)! E|
            """)

        #expect(notes.map(\.startPitch) == [.c4, .d4, .e4])
        #expect(notes[1].duration == beats(frac(1, 2)))
        #expect(notes.map(\.ornamentation?.ornament?.sign) == [.trill, .trill, nil])
        #expect(notes[0].ornamentation?.ornament?.partner == .step(.above, written: nil))
    }
}
