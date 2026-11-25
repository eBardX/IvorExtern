// © 2026 John Gary Pusey (see LICENSE.md)

import Foundation
@testable import IvorExtern
import IvorModel
import IvorMXL
import IvorTiming
import IvorTuning
import Testing
import XestiNumbers
import XestiTools

// Writing ornamentation as MusicXML, round trips, and the warnings for what MusicXML can't hold.
struct MusicXMLExporterOrnamentWriterTests {
}

// MARK: -

extension MusicXMLExporterOrnamentWriterTests {
    @Test
    func roundTrip_everyOrnament() throws {
        let graceD = #"<note><grace slash="yes"/><pitch><step>D</step><octave>4</octave></pitch><voice>1</voice><type>eighth</type></note>"#
        let graceF = #"""
            <note><grace steal-time-following="25"/><chord/><pitch><step>F</step><octave>4</octave></pitch>
            <voice>1</voice><type>eighth</type></note>
            """#
        let trill = #"<ornaments><trill-mark start-note="main" trill-step="half" beats="4"/><accidental-mark>sharp</accidental-mark></ornaments>"#
        let rest = #"<note><rest/><duration>4</duration><voice>1</voice><notations><fermata>square</fermata></notations></note>"#
        let flatMordent = #"<ornaments><mordent/><accidental-mark>flat</accidental-mark></ornaments>"#
        let work = try readMusicXMLDocument([graceD,
                                             graceF,
                                             musicXMLNoteItem("C", 4, notations: trill),
                                             musicXMLNoteItem("D", 4, notations: #"<ornaments><inverted-mordent long="yes"/></ornaments>"#),
                                             musicXMLNoteItem("E",
                                                              4,
                                                              notations: flatMordent),
                                             musicXMLNoteItem("F",
                                                              4,
                                                              type: "quarter",
                                                              notations: #"<ornaments><tremolo type="single">2</tremolo></ornaments>"#),
                                             musicXMLNoteItem("C", 4, notations: #"<arpeggiate direction="down"/><fermata>angled</fermata>"#),
                                             musicXMLNoteItem("E",
                                                              4,
                                                              chord: true,
                                                              notations: #"<arpeggiate direction="down"/><fermata>angled</fermata>"#),
                                             musicXMLNoteItem("G", 4, notations: "<articulations><caesura/></articulations>"),
                                             rest,
                                             musicXMLNoteItem("B", 4),
                                             #"<barline location="right"><fermata>double-square</fermata></barline>"#])
        let text = try writeMusicXML(work)
        let again = try readMusicXMLText(text)
        let written = try firstPartOrnamentations(work)
        let read = try firstPartOrnamentations(again)
        let writtenMarks = try firstPartMarkTable(work)
        let readMarks = try firstPartMarkTable(again)

        #expect(read == written)
        #expect(readMarks == writtenMarks)
        #expect(writtenMarks.count == 3)
    }

    @Test
    func roundTrip_figureAfterMidMeasure_isBoundBySlur() throws {
        let grace = #"<note><grace steal-time-previous="20"/><pitch><step>D</step><octave>4</octave></pitch><voice>1</voice></note>"#
        let work = try readMusicXMLDocument([musicXMLNoteItem("C", 4), grace, musicXMLNoteItem("E", 4)])
        let text = try writeMusicXML(work)
        let again = try readMusicXMLText(text)
        let notes = try #require(standardBeatParts(of: again)?.first).noteTable

        #expect(text.components(separatedBy: "<slur ").count == 3)
        #expect(notes.map { $0.ornamentation?.graceAfter?.pitches } == [[.d4], nil])
        let fifth = try #require(Proportion(numberValue: Number(numerator: 1, denominator: 5)))

        #expect(notes.map { $0.ornamentation?.graceAfter?.events.first?.execution } == [.init(fromMain: .share(fifth)), nil])
        #expect(notes.map(\.extras) == [nil, nil])
    }

    @Test
    func roundTrip_longTrill_hasAWavyLineOverItsPieces() throws {
        var part = Part<BeatTime, Pitch>(name: "P")
        let trill = try #require(BeatNotes.Ornament(sign: .trill, partner: .step(.above, written: nil)))

        try part.noteTable.insert(attack: beat(1, 2), duration: dur(1, 1), pitch: .c4, ornamentation: .init(ornament: trill))

        let work = try Work(name: "Metered",
                            content: .standardBeat([part], TempoMap(), meterTable([(.zero, "4/4")]), KeyTable()))
        let text = try writeMusicXML(work)

        #expect(text.contains(#"<wavy-line type="start"/>"#))
        #expect(text.contains(#"<wavy-line type="stop"/>"#))
        #expect(try firstPartOrnamentations(readMusicXMLText(text)) == [.init(ornament: trill)])
    }

    @Test
    func roundTrip_twoNoteTremolo() throws {
        let timeModification = "<time-modification><actual-notes>2</actual-notes><normal-notes>1</normal-notes></time-modification>"
        let start = #"<ornaments><tremolo type="start">3</tremolo></ornaments>"#
        let stop = #"<ornaments><tremolo type="stop">3</tremolo></ornaments>"#
        let work = try readMusicXMLDocument([musicXMLNoteItem("C", 4, type: "half", extra: timeModification, notations: start),
                                             musicXMLNoteItem("E", 4, type: "half", extra: timeModification, notations: stop),
                                             musicXMLNoteItem("G", 4, duration: 8)])
        let text = try writeMusicXML(work)

        #expect(text.contains(#"<tremolo type="start">3</tremolo>"#))
        #expect(text.contains("<actual-notes>2</actual-notes>"))
        #expect(try firstPartOrnamentations(readMusicXMLText(text)) == firstPartOrnamentations(work))
    }

    @Test
    func warnings_caesuraKept_rateAndDiatonicRuleDropped() throws {
        var part = Part<BeatTime, Pitch>(name: "P")
        let rate = try #require(NotesPerSecond(numberValue: 8))
        let trill = try #require(BeatNotes.Ornament(sign: .trill,
                                                    partner: .step(.above, written: nil),
                                                    execution: .init(partnerRule: .diatonic, rate: .perSecond(rate))))

        try part.noteTable.insert(attack: 0, duration: dur(1, 4), pitch: .c4, ornamentation: .init(ornament: trill))
        part.noteTable.insert(attack: beat(1, 4), duration: dur(1, 4), pitch: .d4)
        part.markTable.insert(time: beat(1, 4), mark: .caesura(nil))

        let work = standardBeatWork(parts: [part])

        #expect(try writeMusicXML(work).contains("<caesura"))
        #expect(try musicXMLExportWarnings(work) == [ExternWarning(kind: .droppedExecution, count: 1, workIndex: 0)])
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

        let warnings = try musicXMLExportWarnings(standardBeatWork(parts: [upper, lower]))

        #expect(warnings == [ExternWarning(kind: .droppedOrnament, count: 1, workIndex: 0),
                             ExternWarning(kind: .splitArpeggio, count: 1, workIndex: 0)])
    }
}
