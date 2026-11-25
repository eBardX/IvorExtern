// © 2026 John Gary Pusey (see LICENSE.md)

import Foundation
@testable import IvorExtern
import IvorModel
import IvorTiming
import IvorTuning
import Testing
import XestiNumbers
import XestiTools

// Writing ornamentation as ABC, round trips, and the warnings for what ABC can't hold.
struct ABCExporterOrnamentsTests {
}

// MARK: -

extension ABCExporterOrnamentsTests {
    @Test
    func roundTrip_everyOrnament() throws {
        let work = try readABC("""
            X:1
            T:Tune
            L:1/4
            K:C
            {D}C {/DE}C {[DF]E}E {C-}C|TC !uppermordent!D !lowermordent!E !arpeggio![CEG]|!//!C !fermata!C H[EG] z|
            """)
        let text = try writeABC(work)
        let again = try readABC(text)

        #expect(text.contains("{D}C"))
        #expect(text.contains("{/DE}C"))
        #expect(text.contains("{[DF]E}E"))
        #expect(text.contains("!uppermordent!"))
        #expect(text.contains("!lowermordent!"))
        #expect(text.contains("!arpeggio!"))
        #expect(text.contains("!//!"))
        #expect(try firstPartOrnamentations(again) == firstPartOrnamentations(work))
    }

    @Test
    func roundTrip_fermataMarksOnARestAndBeforeABarLine() throws {
        let work = try readABC("""
            X:1
            T:Tune
            L:1/4
            M:2/4
            K:C
            C !fermata!z|D E !fermata!|F G|
            """)
        let text = try writeABC(work)
        let part = try #require(standardBeatParts(of: readABC(text))?.first)

        #expect(text.components(separatedBy: "!fermata!").count == 3)
        #expect(part.markTable.map(\.time) == [beatTime(frac(1, 4)), beatTime(frac(3, 4))])
    }

    @Test
    func roundTrip_twoNoteTremolo() throws {
        let work = try readABC("""
            X:1
            T:Tune
            L:1/8
            K:C
            C2!trem2!E2 G|
            """)
        let text = try writeABC(work)

        #expect(text.contains("!trem2!"))
        #expect(try firstPartOrnamentations(readABC(text)) == firstPartOrnamentations(work))
    }

    @Test
    func warnings_caesuraFermataAndExecutionsAreDropped() throws {
        var part = Part<BeatTime, Pitch>(name: "P")
        let trill = try #require(BeatNotes.Ornament(sign: .trill,
                                                    partner: .step(.above, written: nil),
                                                    execution: .init(startNote: .partner)))

        try part.noteTable.insert(attack: 0, duration: beats(frac(1, 4)), pitch: .c4, ornamentation: .init(ornament: trill))
        part.noteTable.insert(attack: beatTime(frac(1, 4)), duration: beats(frac(1, 4)), pitch: .d4)
        part.markTable.insert(time: beatTime(frac(1, 8)), mark: .caesura(nil))
        part.markTable.insert(time: beatTime(frac(1, 8)), mark: .fermata(Fermata(), span: PositiveDuration(beats(frac(1, 16))).unsafelyUnwrapped))

        let warnings = try abcExportWarnings(standardBeatWork(parts: [part]))

        #expect(warnings == [ExternWarning(kind: .droppedCaesura, count: 1, workIndex: 0),
                             ExternWarning(kind: .droppedExecution, count: 1, workIndex: 0),
                             ExternWarning(kind: .droppedFermata, count: 1, workIndex: 0)])
    }

    @Test
    func warnings_figureAfterMovesToTheNextNote() throws {
        let work = try readABC("""
            X:1
            T:Tune
            L:1/4
            K:C
            C {D}z E|
            """)
        let text = try writeABC(work)
        let again = try #require(standardBeatParts(of: readABC(text))?.first)

        #expect(text.contains("{D}E"))
        #expect(again.noteTable.map { $0.ornamentation?.graceBefore?.pitches } == [nil, [.d4]])
        #expect(try abcExportWarnings(work) == [ExternWarning(kind: .movedFigureAfterNote, count: 1, workIndex: 0)])
    }

    @Test
    func warnings_splitRollAndUnsignedOrnament() throws {
        var upper = Part<BeatTime, Pitch>(name: "Upper")
        var lower = Part<BeatTime, Pitch>(name: "Lower")
        let roll = BeatNotes.Ornamentation(arpeggio: BeatNotes.Arpeggio(group: 1))
        let lowerTrill = try #require(BeatNotes.Ornament(partner: .step(.below, written: nil)))

        try upper.noteTable.insert(attack: 0, duration: beats(frac(1, 4)), pitch: .c5, ornamentation: roll)
        try lower.noteTable.insert(attack: 0, duration: beats(frac(1, 4)), pitch: .c4, ornamentation: roll)
        try lower.noteTable.insert(attack: 0, duration: beats(frac(1, 4)), pitch: .e4, ornamentation: roll)
        try lower.noteTable.insert(attack: beatTime(frac(1, 4)),
                                   duration: beats(frac(1, 4)),
                                   pitch: .g4,
                                   ornamentation: .init(ornament: lowerTrill))

        #expect(try abcExportWarnings(standardBeatWork(parts: [upper, lower])) == [ExternWarning(kind: .droppedOrnament, count: 1, workIndex: 0),
                                                                                   ExternWarning(kind: .splitArpeggio, count: 1, workIndex: 0)])
    }
}
