// © 2026 John Gary Pusey (see LICENSE.md)

import Foundation
@testable import IvorExtern
import IvorModel
import IvorTiming
import IvorTuning
import Testing
import XestiNumbers

// Reading MusicXML's grace notes, trills, mordents, tremolos, rolls, fermatas and caesuras into
// ornamentation and part marks.
struct MusicXMLImporterWalkerOrnamentsTests {
}

// MARK: -

extension MusicXMLImporterWalkerOrnamentsTests {
    @Test
    func arpeggiate_oneGroupPerNumberAtEachAttack_sharedByTheVoicesOfAPart() throws {
        let down = #"<arpeggiate direction="down"/>"#
        let first = [mxlNote("C", 4, 4, voice: 1, notations: down),
                     mxlNote("E", 4, 4, voice: 1, chord: true, notations: down),
                     "<backup><duration>4</duration></backup>",
                     mxlNote("C", 3, 4, voice: 2, notations: "<arpeggiate/>")]
        let parts = try musicXMLImportedTwoParts(eachInOnePart: [first, [mxlNote("G", 4, 4, notations: "<arpeggiate/>")]])

        #expect(parts.map { $0.noteTable.map { $0.ornamentation?.arpeggio?.group.uintValue } } == [[1, 1], [1], [2]])
        #expect(parts[0].noteTable.map { $0.ornamentation?.arpeggio?.direction } == [.down, .down])
    }

    @Test
    func caesura_isAPartMarkAtTheRelease() throws {
        let part = try musicXMLImportedPart([mxlNote("C", 4, 4, notations: "<articulations><caesura/></articulations>"),
                                             mxlNote("D", 4, 4)])

        #expect(part.markTable.map(\.time) == [beat(1, 4)])
        #expect(part.markTable.map(\.mark) == [.caesura(nil)])
    }

    @Test
    func chordToneAfterAGraceNote_joinsTheChordBeforeIt() throws {
        let part = try musicXMLImportedPart([mxlNote("C", 4, 4),
                                             mxlGrace("D", 4),
                                             mxlNote("E", 4, 4, chord: true)])

        #expect(part.noteTable.map(\.attack) == [.zero, .zero])
        #expect(part.noteTable.map(\.duration) == [dur(1, 4), dur(1, 4)])
    }

    @Test
    func fermata_onABarLine_isAMarkOverTheLastEvent() throws {
        let part = try musicXMLImportedPart([mxlNote("C", 4, 8),
                                             mxlNote("D", 4, 8),
                                             #"<barline location="right"><fermata type="inverted">angled</fermata></barline>"#])

        #expect(part.noteTable.allSatisfy { $0.ornamentation == nil })
        #expect(part.markTable.map(\.time) == [beat(1, 2)])
        #expect(try part.markTable.map(\.mark) == [.fermata(Fermata(shape: .short), span: #require(PositiveDuration(dur(1, 2))))])
    }

    @Test
    func fermata_onARest_isAMarkOverTheRest() throws {
        let rest = "<note><rest/><duration>4</duration><voice>1</voice><notations><fermata>square</fermata></notations></note>"
        let part = try musicXMLImportedPart([mxlNote("C", 4, 4),
                                             rest,
                                             mxlNote("D", 4, 4)])

        #expect(part.noteTable.allSatisfy { $0.ornamentation == nil })
        #expect(part.markTable.map(\.time) == [beat(1, 4)])
        #expect(try part.markTable.map(\.mark) == [.fermata(Fermata(shape: .long), span: #require(PositiveDuration(dur(1, 4))))])
    }

    @Test(arguments: [("normal", FermataShape.normal),
                      ("angled", .short),
                      ("square", .long),
                      ("double-angled", .veryShort),
                      ("double-square", .veryLong),
                      ("half-curve", .normal)])
    func fermata_shapes(_ text: String, _ shape: FermataShape) throws {
        let part = try musicXMLImportedPart([mxlNote("C", 4, 4, notations: #"<fermata type="inverted">\#(text)</fermata>"#)])

        #expect(part.noteTable.first?.ornamentation?.fermata == Fermata(shape: shape))
    }

    @Test
    func grace_afterTheNoteBefore_underEachRule() throws {
        let stealsPrevious = try musicXMLImportedPart([mxlNote("C", 4, 4),
                                                       mxlGrace("D", attributes: #"steal-time-previous="20""#),
                                                       mxlNote("E", 4, 4)])
        let endsASlur = try musicXMLImportedPart([mxlNote("C", 4, 4, notations: #"<slur type="start" number="2"/>"#),
                                                  mxlGrace("D", notations: #"<slur type="stop" number="2"/>"#),
                                                  mxlNote("E", 4, 4)])
        let endsTheMeasure = try musicXMLImportedPart(measures: [[mxlNote("C", 4, 16), mxlGrace("D")], [mxlNote("E", 4, 16)]])
        let comesBeforeARest = try musicXMLImportedPart([mxlNote("C", 4, 4),
                                                         mxlGrace("D"),
                                                         "<note><rest/><duration>4</duration><voice>1</voice></note>",
                                                         mxlNote("E", 4, 4)])

        for part in [stealsPrevious, endsASlur, endsTheMeasure, comesBeforeARest] {
            #expect(part.noteTable.map { $0.ornamentation?.graceAfter?.pitches } == [[.d4], nil])
            #expect(part.noteTable.map { $0.ornamentation?.graceBefore } == [nil, nil])
        }

        #expect(endsASlur.noteTable.first?.extras == nil)
        #expect(try stealsPrevious.noteTable.first?.ornamentation?.graceAfter?.events.first?.execution
            == .init(fromMain: .share(#require(Proportion(numberValue: Number(numerator: 1, denominator: 5))))))
    }

    @Test
    func grace_betweenTiedNotes_breaksTheTie() throws {
        let part = try musicXMLImportedPart([mxlNote("C", 4, 4, tie: "start"),
                                             mxlGrace("D"),
                                             mxlNote("C", 4, 4, tie: "stop")])

        #expect(part.noteTable.map(\.duration) == [dur(1, 4), dur(1, 4)])
        #expect(part.noteTable.map { $0.ornamentation?.graceBefore?.pitches } == [nil, [.d4]])
    }

    @Test
    func grace_makeTime_becomesAShareOfTheMainNote() throws {
        let part = try musicXMLImportedPart([mxlGrace("D", attributes: #"make-time="2""#),
                                             mxlNote("C", 4, 4)])
        let half = try #require(Proportion(numberValue: Number(numerator: 1, denominator: 2)))

        #expect(part.noteTable.first?.ornamentation?.graceBefore?.events.first?.execution == .init(fromMain: .share(half)))
    }

    @Test
    func grace_onAChord_belongsToItsLowestTone() throws {
        let part = try musicXMLImportedPart([mxlGrace("D"),
                                             mxlNote("G", 4, 4),
                                             mxlNote("C", 4, 4, chord: true)])
        let figures = Dictionary(uniqueKeysWithValues: part.noteTable.map { ($0.startPitch, $0.ornamentation?.graceBefore?.pitches) })

        #expect(figures == [.c4: [.d4], .g4: nil])
    }

    @Test
    func grace_runBeforeANote_becomesItsFigure() throws {
        let part = try musicXMLImportedPart([mxlGrace("D", type: "eighth", attributes: #"slash="yes""#),
                                             mxlGrace("F", type: "eighth", chord: true),
                                             mxlGrace("E", type: "16th", dots: 1, attributes: #"steal-time-following="25""#),
                                             mxlNote("C", 4, 4)])
        let figure = try #require(part.noteTable.first?.ornamentation?.graceBefore)
        let quarter = try #require(Proportion(numberValue: Number(numerator: 1, denominator: 4)))

        #expect(part.noteTable.map(\.attack) == [.zero])
        #expect(figure.isSlashed)
        #expect(figure.events.map(\.pitches) == [[.d4, .f4], [.e4]])
        #expect(figure.events.map { $0.length?.duration } == [dur(1, 8), dur(3, 32)])
        #expect(figure.events.map(\.execution) == [nil, .init(fromMain: .share(quarter))])
    }

    @Test
    func grace_tiedIntoItsMainNote() throws {
        let part = try musicXMLImportedPart([mxlGrace("C", tie: "start"),
                                             mxlNote("C", 4, 4, tie: "stop")])

        #expect(part.noteTable.count == 1)
        #expect(part.noteTable.first?.ornamentation?.graceBefore?.isTiedToMainNote == true)
    }

    @Test
    func mordent_long_soundsItsPartnerTwice() throws {
        let part = try musicXMLImportedPart([mxlNote("C", 4, 4, notations: #"<ornaments><inverted-mordent long="yes"/></ornaments>"#)])
        let twice = try #require(AlternationCount(uintValue: 2))

        #expect(part.noteTable.first?.ornamentation?.ornament?.execution == .init(extent: .count(twice)))
    }

    @Test
    func mordent_lowerWithAnAccidentalMark_hasAWrittenPartnerBelow() throws {
        let part = try musicXMLImportedPart([mxlNote("C",
                                                     4,
                                                     4,
                                                     notations: "<ornaments><mordent/><accidental-mark>flat</accidental-mark></ornaments>")])

        #expect(part.noteTable.first?.ornamentation?.ornament?.partner == .step(.below, written: .bFlat3))
    }

    @Test
    func mordent_startNote_isThePartnerOnlyOnItsOwnSide() throws {
        let lowerFromBelow = #"<ornaments><mordent start-note="below"/></ornaments>"#
        let lowerFromUpper = #"<ornaments><mordent start-note="upper"/></ornaments>"#
        let upperFromUpper = #"<ornaments><inverted-mordent start-note="upper"/></ornaments>"#
        let upperFromBelow = #"<ornaments><inverted-mordent start-note="below"/></ornaments>"#
        let items = [mxlNote("C", 4, 4, notations: lowerFromBelow),
                     mxlNote("D", 4, 4, notations: lowerFromUpper),
                     mxlNote("E", 4, 4, notations: upperFromUpper),
                     mxlNote("F", 4, 4, notations: upperFromBelow)]
        let part = try musicXMLImportedPart(items)

        #expect(part.noteTable.map { $0.ornamentation?.ornament?.execution?.startNote } == [.partner, nil, .partner, nil])
        #expect(try musicXMLImportWarnings(items) == [ExternWarning(kind: .droppedExecution, count: 2, workIndex: 0)])
    }

    @Test
    func nonArpeggiate_isDroppedWithAWarning() throws {
        let warnings = try musicXMLImportWarnings([mxlNote("C", 4, 4, notations: #"<non-arpeggiate type="bottom"/>"#),
                                                   mxlNote("E", 4, 4, chord: true, notations: #"<non-arpeggiate type="top"/>"#)])

        #expect(warnings == [ExternWarning(kind: .droppedNonArpeggiate, count: 1, workIndex: 0)])
    }

    @Test
    func tremolo_single_addsTheNotesFlagsToItsMarks() throws {
        let part = try musicXMLImportedPart([mxlNote("C",
                                                     4,
                                                     2,
                                                     type: "eighth",
                                                     notations: #"<ornaments><tremolo type="single">2</tremolo></ornaments>"#),
                                             mxlNote("D", 4, 2, notations: #"<ornaments><tremolo type="unmeasured">0</tremolo></ornaments>"#)])
        let three = try #require(TremoloStrokes(uintValue: 3))

        #expect(part.noteTable.map { $0.ornamentation?.ornament?.sign } == [.tremolo(.measured(three)), .tremolo(.unmeasured)])
        #expect(part.noteTable.map { $0.ornamentation?.ornament?.partner } == [.repeat, .repeat])
    }

    @Test
    func tremolo_twoNotes_joinIntoOneNoteWithItsPartner() throws {
        let timeModification = "<time-modification><actual-notes>2</actual-notes><normal-notes>1</normal-notes></time-modification>"
        let part = try musicXMLImportedPart([mxlNote("C",
                                                     4,
                                                     4,
                                                     type: "half",
                                                     extra: timeModification,
                                                     notations: #"<ornaments><tremolo type="start">3</tremolo></ornaments>"#),
                                             mxlNote("E",
                                                     4,
                                                     4,
                                                     type: "half",
                                                     extra: timeModification,
                                                     notations: #"<ornaments><tremolo type="stop">3</tremolo></ornaments>"#),
                                             mxlNote("G", 4, 4)])
        let three = try #require(TremoloStrokes(uintValue: 3))

        #expect(part.noteTable.map(\.startPitch) == [.c4, .g4])
        #expect(part.noteTable.map(\.duration) == [dur(1, 2), dur(1, 4)])
        #expect(part.noteTable.first?.ornamentation?.ornament == .init(sign: .tremolo(.measured(three)), partner: .pitches([.e4])))
    }

    @Test
    func trill_accidentalMark_isTheWrittenPartner() throws {
        let part = try musicXMLImportedPart([mxlNote("C",
                                                     4,
                                                     4,
                                                     notations: "<ornaments><trill-mark/><accidental-mark>sharp</accidental-mark></ornaments>")])

        #expect(part.noteTable.first?.ornamentation?.ornament?.partner == .step(.above, written: .dSharp4))
    }

    @Test
    func trill_trillSound_becomesItsExecution() throws {
        let mainHalf = #"<ornaments><trill-mark start-note="main" trill-step="half" beats="5"/></ornaments>"#
        let part = try musicXMLImportedPart([mxlNote("C", 4, 4, notations: mainHalf),
                                             mxlNote("D", 4, 4, notations: #"<ornaments><trill-mark start-note="upper" beats="4"/></ornaments>"#),
                                             mxlNote("E", 4, 4, notations: #"<ornaments><trill-mark last-beat="50"/></ornaments>"#)])
        let two = try #require(AlternationCount(uintValue: 2))
        let half = try #require(Proportion(numberValue: Number(numerator: 1, denominator: 2)))

        #expect(part.noteTable.map { $0.ornamentation?.ornament?.execution } == [.init(startNote: .main, partnerRule: .halfStep, extent: .count(two)),
                                                                                 .init(startNote: .partner, extent: .count(two)),
                                                                                 .init(extent: .span(half))])
    }

    @Test
    func trill_unsupportedTrillSound_isDroppedWithWarnings() throws {
        let unison = #"<ornaments><trill-mark trill-step="unison" accelerate="yes"/></ornaments>"#
        let warnings = try musicXMLImportWarnings([mxlNote("C", 4, 4, notations: #"<ornaments><trill-mark start-note="below"/></ornaments>"#),
                                                   mxlNote("D", 4, 4, notations: unison),
                                                   mxlNote("E", 4, 4, notations: #"<ornaments><trill-mark two-note-turn="whole"/></ornaments>"#)])

        #expect(warnings == [ExternWarning(kind: .droppedExecution, count: 4, workIndex: 0)])
    }

    @Test
    func wavyLine_putsTheTrillOnEveryNoteUntilItsStop() throws {
        let start = #"<ornaments><trill-mark/><accidental-mark>flat</accidental-mark><wavy-line type="start"/></ornaments>"#
        let part = try musicXMLImportedPart([mxlNote("C", 4, 4, notations: start),
                                             mxlNote("D", 4, 4),
                                             mxlNote("E", 4, 4, notations: #"<ornaments><wavy-line type="stop"/></ornaments>"#),
                                             mxlNote("F", 4, 4)])

        #expect(part.noteTable.map { $0.ornamentation?.ornament?.sign } == [.trill, .trill, .trill, nil])
        #expect(part.noteTable.first?.ornamentation?.ornament?.partner == .step(.above, written: .dFlat4))
    }
}
