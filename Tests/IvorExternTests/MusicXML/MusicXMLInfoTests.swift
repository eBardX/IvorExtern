// © 2026 John Gary Pusey (see LICENSE.md)

import Foundation
@testable import IvorExtern
import IvorModel
import IvorMXL
import IvorTiming
import IvorTuning
import Testing
import XestiTools

struct MusicXMLInfoTests {
}

// MARK: -

extension MusicXMLInfoTests {
    @Test
    func read_creditsOnly_fillWhatIdentificationLacks() throws {
        let work = try _read(header: """
              <credit page="1"><credit-type>title</credit-type><credit-words>Aubade</credit-words></credit>
              <credit page="1"><credit-type>subtitle</credit-type><credit-words>Dawn Song</credit-words></credit>
              <credit page="1"><credit-type>Dedication</credit-type><credit-words>For Anna</credit-words></credit>
              <credit page="1"><credit-type>composer</credit-type><credit-words>J. Smith</credit-words></credit>
              <credit page="1"><credit-type>rights</credit-type><credit-words>© 1998 Acme</credit-words></credit>
              <credit page="1"><credit-words>Untyped</credit-words></credit>
            """)

        #expect(work.info.title == "Aubade")
        #expect(work.info.subtitles == ["Dawn Song"])
        #expect(work.info.dedication == "For Anna")
        #expect(work.info.credits == [Credit(name: "J. Smith", role: .composer)].compactMap(\.self))
        #expect(work.info.rights == [RightsNotice(text: "© 1998 Acme")].compactMap(\.self))
    }

    @Test
    func read_identification_preferredOverCredits() throws {
        let work = try _read(header: """
              <work><work-number>Op. 2</work-number><work-title>Suite</work-title></work>
              <movement-number>3</movement-number>
              <movement-title>Aubade</movement-title>
              <identification>
                <creator type="composer">J. Smith</creator>
                <creator>Anon.</creator>
                <rights type="words">© 1998 Acme</rights>
                <encoding>
                  <encoder>T. Scribe</encoder>
                  <encoding-description>Proofread twice</encoding-description>
                </encoding>
                <source>Manuscript</source>
                <miscellaneous>
                  <miscellaneous-field name="mood">Wistful</miscellaneous-field>
                  <miscellaneous-field name="alternate title">Morning Piece</miscellaneous-field>
                </miscellaneous>
              </identification>
              <credit page="1"><credit-type>title</credit-type><credit-words>Printed Title</credit-words></credit>
              <credit page="1"><credit-type>composer</credit-type><credit-words>Printed Composer</credit-words></credit>
            """)
        let info = work.info

        #expect(info.title == "Aubade")
        #expect(info.parentWorkTitle == "Suite")
        #expect(info.alternateTitles == ["Morning Piece"])
        #expect(info.credits == [Credit(name: "J. Smith", role: .composer),
                                 Credit(name: "Anon."),
                                 Credit(name: "T. Scribe", role: .transcriber)].compactMap(\.self))
        #expect(info.rights == [RightsNotice(text: "© 1998 Acme", scope: .words)].compactMap(\.self))
        #expect(info.remarks == [Remark(text: "Op. 2", label: "work number"),
                                 Remark(text: "3", label: "movement number"),
                                 Remark(text: "Manuscript", label: "source"),
                                 Remark(text: "Proofread twice", label: "encoding description"),
                                 Remark(text: "Wistful", label: "mood")].compactMap(\.self))
    }

    @Test
    func read_scorePart_populatesInstrumentExtras() throws {
        let work = try _read(header: "",
                             scorePart: """
                                <part-name>Flute</part-name>
                                <score-instrument id="P1-I1">
                                  <instrument-name>Flauto 1</instrument-name>
                                  <instrument-abbreviation>Fl. 1</instrument-abbreviation>
                                </score-instrument>
                             """)
        let part = try #require(standardBeatParts(of: work)?.first)
        let entry = try #require(part.instrumentMap.first)

        #expect(stringValue(entry.extras, .instrumentName) == "Flauto 1")
        #expect(stringValue(entry.extras, .instrumentAbbreviation) == "Fl. 1")
    }

    @Test
    func write_info_writesWorkIdentificationAndCredits() throws {
        let score = try MusicXML.Exporter().convert(_sampleWork())
        let identification = try #require(score.identification)

        #expect(score.work?.title == "Collected Pieces")
        #expect(score.work?.number == "Op. 2")
        #expect(score.movementTitle == "Aubade")
        #expect(identification.creator == [MXLTypedText(value: "J. Smith", kind: "composer"),
                                           MXLTypedText(value: "A. Poet", kind: "lyricist")])
        #expect(identification.rights == [MXLTypedText(value: "© 1998 Acme\nLine two", kind: "music")])
        #expect(identification.encoding?.items == [.encoder(MXLTypedText(value: "T. Scribe"))])
        #expect(identification.source == "From a fiddler")
        #expect(identification.miscellaneous?.field == [MXLMiscellaneous.Field(value: "Morning Piece", name: "alternate title"),
                                                        MXLMiscellaneous.Field(value: "A plain remark", name: "remark")])
        #expect(score.credit.map(\.kind) == [["title"], ["subtitle"], ["dedication"]])
    }

    @Test
    func write_noTitle_writesWorkNameAsWorkTitle() throws {
        let score = try MusicXML.Exporter().convert(Work(name: "Sketch 3", content: .standardBeat([], TempoMap())))

        #expect(score.work?.title == "Sketch 3")
        #expect(score.movementTitle == nil)
        #expect(score.identification == nil)
        #expect(score.credit.isEmpty)
    }

    @Test
    func roundTrip_info_preservesWork() throws {
        let work = _sampleWork()
        let recovered = try roundTrip(work,
                                      exporter: MusicXML.Exporter(),
                                      importer: MusicXML.Importer(),
                                      fileFormat: .musicXML)
        let recoveredPart = try namedStandardPart(recovered, "Flute")
        let entry = try #require(recoveredPart.instrumentMap.first)
        var expected = work.info

        // `movement number` and `work number` come back first, since they
        // have elements of their own ahead of `<identification>`.
        expected.remarks = expected.remarks.filter { $0.label == "work number" } + expected.remarks.filter { $0.label != "work number" }

        // IvorMXL collapses the whitespace in an element's text, line
        // breaks included.
        expected.rights = [RightsNotice(text: "© 1998 Acme Line two", scope: .music)].compactMap(\.self)

        #expect(recovered.info == expected)
        #expect(stringValue(entry.extras, .instrumentName) == "Flauto 1")
        #expect(stringValue(entry.extras, .instrumentAbbreviation) == "Fl. 1")
    }
}

// MARK: -

extension MusicXMLInfoTests {
    private func _read(header: String,
                       scorePart: String = "<part-name>Piano</part-name>") throws -> Work {
        let musicXML = """
            <?xml version="1.0" encoding="UTF-8"?>
            <score-partwise version="4.0">
            \(header)
              <part-list>
                <score-part id="P1">\(scorePart)</score-part>
              </part-list>
              <part id="P1">
                <measure number="1">
                  <attributes><divisions>1</divisions></attributes>
                  <note>
                    <pitch><step>C</step><octave>5</octave></pitch>
                    <duration>1</duration>
                    <type>quarter</type>
                  </note>
                </measure>
              </part>
            </score-partwise>
            """
        let works = try MusicXML.Importer().read(from: FileWrapper(regularFileWithContents: Data(musicXML.utf8)), as: .musicXML)

        return try #require(works.first)
    }

    private func _sampleWork() -> Work {
        var instrumentMap = InstrumentMap<BeatTime>()

        instrumentMap.insert(time: .zero,
                             instrument: Instrument("Flute"),
                             extras: Extras(elements: [Extra(name: Extra.instrumentName.name, values: [.string("Flauto 1")]),
                                                       Extra(name: Extra.instrumentAbbreviation.name, values: [.string("Fl. 1")])]))

        let part = Part<BeatTime, Pitch>(name: "Flute",
                                         noteTable: NoteTable(),
                                         instrumentMap: instrumentMap)

        return Work(name: "Collected Pieces: Aubade",
                    content: .standardBeat([part], TempoMap()),
                    info: Work.Info(title: "Aubade",
                                    subtitles: ["Dawn Song"],
                                    alternateTitles: ["Morning Piece"],
                                    parentWorkTitle: "Collected Pieces",
                                    dedication: "To my teacher",
                                    credits: [Credit(name: "J. Smith", role: .composer),
                                              Credit(name: "A. Poet", role: .lyricist),
                                              Credit(name: "T. Scribe", role: .transcriber)].compactMap(\.self),
                                    rights: [RightsNotice(text: "© 1998 Acme\nLine two", scope: .music)].compactMap(\.self),
                                    remarks: [Remark(text: "From a fiddler", label: "source"),
                                              Remark(text: "A plain remark"),
                                              Remark(text: "Op. 2", label: "work number")].compactMap(\.self)))
    }
}
