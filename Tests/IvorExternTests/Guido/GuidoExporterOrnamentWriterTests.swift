// © 2026 John Gary Pusey (see LICENSE.md)

import Foundation
@testable import IvorExtern
import IvorGMN
import IvorModel
import IvorTiming
import IvorTuning
import Testing
import XestiNumbers
import XestiTools

// Writing ornamentation as Guido, round trips, and the warnings for what Guido can't hold.
struct GuidoExporterOrnamentWriterTests {
}

// MARK: -

extension GuidoExporterOrnamentWriterTests {
    @Test
    func roundTrip_everyOrnament() throws {
        let work = try readGuido(#"""
            [ \grace(d1/16) c1/4 \grace({d/16, f} e/32) e/4 \grace(c1/16 \tieEnd) c/4
              \trill<note="b&", dur=32>(a1/4) \mordent(d) \mordent<type="inverted">(e)
              \mordent<type="prallprall">(f) \arpeggio<direction="down">({c/4, e, g})
              \tremolo<style="//">(c/8) \tremolo<speed=64>(c/4) \fermata<type="short">(c/4)
              \fermata<type="long">({e, g}) \fermata(d) ]
            """#)
        let text = try writeGuido(work)

        #expect(text.contains(#"\grace"#))
        #expect(text.contains(#"\trill<"b&",dur=32>"#))
        #expect(text.contains(#"\mordent<type="inverted">"#))
        #expect(text.contains(#"\mordent<type="prallprall">"#))
        #expect(text.contains(#"\arpeggio<"down">"#))
        #expect(text.contains(#"\tremolo<"//",32>(c1*1/8)"#))
        #expect(text.contains(#"\fermata<"short">"#))
        #expect(try firstPartOrnamentations(readGuido(text)) == firstPartOrnamentations(work))
    }

    @Test
    func roundTrip_fermataMarksOnARestAndOnBarLines() throws {
        let work = try readGuido(#"[ \meter<"3/4"> c1/4 \fermata(_/4) d \bar e f \fermata(\bar) g/2 \fermata<type="long">(a/4) ]"#)
        let text = try writeGuido(work)
        let part = try #require(standardBeatParts(of: readGuido(text))?.first)

        #expect(text.contains(#"\fermata(_*1/4)"#))
        #expect(text.contains(#"\fermata(|)"#))
        #expect(part.markTable.map(\.time) == [beat(1, 4), beat(1, 1)])
        #expect(part.noteTable.map { $0.ornamentation?.fermata?.shape } == [nil, nil, nil, nil, nil, .long])
    }

    @Test
    func roundTrip_twoNoteTremolo() throws {
        let work = try readGuido(#"[ \tremolo<pitch="g", speed=32>(c1/8) e/4 ]"#)
        let text = try writeGuido(work)

        #expect(text.contains(#"\tremolo<"//",32,"g1">(c1*1/8)"#))
        #expect(try firstPartOrnamentations(readGuido(text)) == firstPartOrnamentations(work))
        #expect(try standardBeatParts(of: readGuido(text))?.first?.noteTable.map(\.duration) == [dur(1, 4), dur(1, 4)])
    }

    @Test
    func warnings_caesuraFermataAndExecutionsAreDropped() throws {
        var part = Part<BeatTime, Pitch>(name: "P")
        let trill = try #require(BeatNotes.Ornament(sign: .trill,
                                                    partner: .step(.above, written: nil),
                                                    execution: .init(startNote: .partner)))

        try part.noteTable.insert(attack: 0, duration: dur(1, 4), pitch: .c4, ornamentation: .init(ornament: trill))
        part.noteTable.insert(attack: beat(1, 4), duration: dur(1, 4), pitch: .d4)
        part.markTable.insert(time: beat(1, 8), mark: .caesura(nil))
        try part.markTable.insert(time: beat(1, 8), mark: .fermata(Fermata(), span: #require(PositiveDuration(dur(1, 16)))))

        #expect(try guidoExportWarnings(standardBeatWork(parts: [part])) == [ExternWarning(kind: .droppedCaesura, count: 1, workIndex: 0),
                                                                             ExternWarning(kind: .droppedExecution, count: 1, workIndex: 0),
                                                                             ExternWarning(kind: .droppedFermata, count: 1, workIndex: 0)])
    }

    @Test
    func warnings_figureAfterMovesToTheNextNote_andLosesItsSlash() throws {
        var part = Part<BeatTime, Pitch>(name: "P")
        let event = try #require(BeatNotes.GraceFigure.Event(pitches: [.d4]))
        let figure = try #require(BeatNotes.GraceFigure(events: [event], isSlashed: true))

        try part.noteTable.insert(attack: 0, duration: dur(1, 4), pitch: .c4, ornamentation: .init(graceAfter: figure))
        part.noteTable.insert(attack: beat(1, 2), duration: dur(1, 4), pitch: .e4)

        let work = standardBeatWork(parts: [part])
        let again = try #require(standardBeatParts(of: readGuido(writeGuido(work)))?.first)

        #expect(again.noteTable.map { $0.ornamentation?.graceBefore?.pitches } == [nil, [.d4]])
        #expect(try guidoExportWarnings(work) == [ExternWarning(kind: .droppedSlash, count: 1, workIndex: 0),
                                                  ExternWarning(kind: .movedFigureAfterNote, count: 1, workIndex: 0)])
    }

    @Test
    func warnings_rateInNotesPerSecondIsDropped() throws {
        var part = Part<BeatTime, Pitch>(name: "P")
        let rate = try #require(NotesPerSecond(numberValue: 8))
        let trill = try #require(BeatNotes.Ornament(sign: .trill,
                                                    partner: .step(.above, written: nil),
                                                    execution: .init(rate: .perSecond(rate))))

        try part.noteTable.insert(attack: 0, duration: dur(1, 4), pitch: .c4, ornamentation: .init(ornament: trill))

        let work = standardBeatWork(parts: [part])

        #expect(try writeGuido(work).contains(#"\trill(c1*1/4)"#))
        #expect(try guidoExportWarnings(work) == [ExternWarning(kind: .droppedExecution, count: 1, workIndex: 0)])
    }

    @Test
    func warnings_splitRollAndUnsignedOrnament() throws {
        var upper = Part<BeatTime, Pitch>(name: "Upper")
        var lower = Part<BeatTime, Pitch>(name: "Lower")
        let roll = BeatNotes.Ornamentation(arpeggio: BeatNotes.Arpeggio(group: 1))
        let lowerTrill = try #require(BeatNotes.Ornament(partner: .step(.below, written: nil)))

        try upper.noteTable.insert(attack: 0, duration: dur(1, 4), pitch: .c5, ornamentation: roll)
        try lower.noteTable.insert(attack: 0, duration: dur(1, 4), pitch: .c4, ornamentation: roll)
        try lower.noteTable.insert(attack: 0, duration: dur(1, 4), pitch: .e4, ornamentation: roll)
        try lower.noteTable.insert(attack: beat(1, 4), duration: dur(1, 4), pitch: .g4, ornamentation: .init(ornament: lowerTrill))

        #expect(try guidoExportWarnings(standardBeatWork(parts: [upper, lower])) == [ExternWarning(kind: .droppedOrnament, count: 1, workIndex: 0),
                                                                                     ExternWarning(kind: .splitArpeggio, count: 1, workIndex: 0)])
    }
}
