// © 2025–2026 John Gary Pusey (see LICENSE.md)

import Foundation
@testable import IvorExtern
import IvorModel
import IvorMXL
import IvorTiming
import IvorTuning
import Testing
import XestiNumbers
import XestiTools

// swiftlint:disable file_length

struct MusicXMLImporterTests {
}

// MARK: -

extension MusicXMLImporterTests {
    @Test
    func read_change_isOffThenOnAtOneTime() throws {
        let pedals = try musicXMLImportedPedals(["<pedal type=\"start\"/>",
                                                 "<pedal type=\"change\"/>",
                                                 "<pedal type=\"stop\"/>"])

        #expect(pedals[.sustain]?.map(\.time) == [0, 1, 1, 2])
        #expect(pedals[.sustain]?.map(\.level) == [.down, .up, .down, .up])
    }

    @Test
    func read_continueDiscontinueResume_leaveTheLevelAlone() throws {
        let pedals = try musicXMLImportedPedals(["<pedal type=\"start\"/>",
                                                 "<pedal type=\"discontinue\"/>",
                                                 "<pedal type=\"resume\"/>",
                                                 "<pedal type=\"continue\"/>"])

        #expect(pedals[.sustain]?.map(\.level) == [.down])
    }

    @Test
    func read_creditsOnly_fillWhatIdentificationLacks() throws {
        let work = try readMusicXML(header: """
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
    func read_directionDynamics_populatesDynamicMap_whenNoNoteHasDynamics() throws {
        let musicXML = """
            <?xml version="1.0" encoding="UTF-8"?>
            <score-partwise version="4.0">
              <part-list>
                <score-part id="P1"><part-name>Piano</part-name></score-part>
              </part-list>
              <part id="P1">
                <measure number="1">
                  <attributes><divisions>1</divisions></attributes>
                  <direction><direction-type><dynamics><mf/></dynamics></direction-type></direction>
                  <note>
                    <pitch><step>C</step><octave>5</octave></pitch>
                    <duration>1</duration>
                    <type>quarter</type>
                  </note>
                </measure>
              </part>
            </score-partwise>
            """
        let wrapper = FileWrapper(regularFileWithContents: Data(musicXML.utf8))
        let works = try MusicXML.Importer().read(from: wrapper, as: .musicXML)
        let work = try #require(works.first)

        guard case let .standardBeat(parts, _) = work.content
        else { Issue.record("Expected standardBeat content"); return }

        #expect(parts.first?.dynamicMap[.zero] == .mf)
    }

    @Test
    func read_emptyData_throws() {
        let wrapper = FileWrapper(regularFileWithContents: Data())

        #expect(throws: (any Error).self) {
            try MusicXML.Importer().read(from: wrapper, as: .musicXML)
        }
    }

    @Test
    func read_identification_preferredOverCredits() throws {
        let work = try readMusicXML(header: """
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
    func read_interleavedNumbers_pairStopWithItsOpener() throws {
        let pedals = try musicXMLImportedPedals(["<pedal type=\"start\" number=\"1\"/>",
                                                 "<pedal type=\"sostenuto\" number=\"2\"/>",
                                                 "<pedal type=\"stop\" number=\"1\"/>",
                                                 "<pedal type=\"stop\" number=\"2\"/>"])

        #expect(pedals[.sustain]?.map(\.time) == [0, 2])
        #expect(pedals[.sustain]?.map(\.level) == [.down, .up])
        #expect(pedals[.sostenuto]?.map(\.time) == [1, 3])
        #expect(pedals[.sostenuto]?.map(\.level) == [.down, .up])
    }

    @Test
    func read_metronomeMark_populatesTempoMap_whenNoSoundTempo() throws {
        let musicXML = """
            <?xml version="1.0" encoding="UTF-8"?>
            <score-partwise version="4.0">
              <part-list>
                <score-part id="P1">
                  <part-name>Piano</part-name>
                </score-part>
              </part-list>
              <part id="P1">
                <measure number="1">
                  <attributes>
                    <divisions>1</divisions>
                  </attributes>
                  <direction>
                    <direction-type>
                      <metronome>
                        <beat-unit>quarter</beat-unit>
                        <per-minute>96</per-minute>
                      </metronome>
                    </direction-type>
                  </direction>
                  <note>
                    <pitch><step>C</step><octave>5</octave></pitch>
                    <duration>1</duration>
                    <type>quarter</type>
                  </note>
                </measure>
              </part>
            </score-partwise>
            """
        let wrapper = FileWrapper(regularFileWithContents: Data(musicXML.utf8))
        let works = try MusicXML.Importer().read(from: wrapper, as: .musicXML)
        let work = try #require(works.first)

        guard case let .standardBeat(_, tempoMap) = work.content
        else { Issue.record("Expected standardBeat content"); return }

        #expect(tempoMap[.zero] == Tempo(uintValue: 96))
    }

    @Test
    func read_midiInstrumentChannelAndBank_populatesExtras() throws {
        let musicXML = """
            <?xml version="1.0" encoding="UTF-8"?>
            <score-partwise version="4.0">
              <part-list>
                <score-part id="P1">
                  <part-name>Violin</part-name>
                  <score-instrument id="P1-I1"><instrument-name>Violin</instrument-name></score-instrument>
                  <midi-instrument id="P1-I1"><midi-channel>3</midi-channel><midi-bank>131</midi-bank></midi-instrument>
                </score-part>
              </part-list>
              <part id="P1">
                <measure number="1">
                  <attributes><divisions>1</divisions></attributes>
                  <note><pitch><step>C</step><octave>5</octave></pitch><duration>1</duration><type>quarter</type></note>
                </measure>
              </part>
            </score-partwise>
            """
        let wrapper = FileWrapper(regularFileWithContents: Data(musicXML.utf8))
        let works = try MusicXML.Importer().read(from: wrapper, as: .musicXML)
        let work = try #require(works.first)

        guard case let .standardBeat(parts, _) = work.content
        else { Issue.record("Expected standardBeat content"); return }

        let foundChannel = intValue(parts.first?.extras, .midiChannel)
        var foundBank: Int?

        for entry in parts.first?.instrumentTable ?? InstrumentTable() {
            foundBank = intValue(entry.extras, .midiBank)
        }

        #expect(foundChannel == 3)
        // `<midi-bank>131</midi-bank>` numbers from 1.
        #expect(foundBank == 130)
    }

    @Test
    func read_midiInstrumentChannelOnlyNoNameOrProgram_putsChannelExtraOnPart() throws {
        let musicXML = """
            <?xml version="1.0" encoding="UTF-8"?>
            <score-partwise version="4.0">
              <part-list>
                <score-part id="P1">
                  <part-name>Unnamed</part-name>
                  <midi-instrument id="P1-I1"><midi-channel>5</midi-channel></midi-instrument>
                </score-part>
              </part-list>
              <part id="P1">
                <measure number="1">
                  <attributes><divisions>1</divisions></attributes>
                  <note><pitch><step>C</step><octave>5</octave></pitch><duration>1</duration><type>quarter</type></note>
                </measure>
              </part>
            </score-partwise>
            """
        let wrapper = FileWrapper(regularFileWithContents: Data(musicXML.utf8))
        let works = try MusicXML.Importer().read(from: wrapper, as: .musicXML)
        let work = try #require(works.first)

        guard case let .standardBeat(parts, _) = work.content
        else { Issue.record("Expected standardBeat content"); return }

        #expect(parts.first?.instrumentTable.isEmpty == true)
        #expect(intValue(parts.first?.extras, .midiChannel) == 5)
    }

    @Test
    func read_multiplePartsWithEmptyPartNames_fallsBackToVoiceN() throws {
        let musicXML = """
            <?xml version="1.0" encoding="UTF-8"?>
            <score-partwise version="4.0">
              <part-list>
                <score-part id="P1"><part-name></part-name></score-part>
                <score-part id="P2"><part-name>Cello</part-name></score-part>
                <score-part id="P3"><part-name></part-name></score-part>
              </part-list>
              <part id="P1">
                <measure number="1">
                  <attributes><divisions>1</divisions></attributes>
                  <note><pitch><step>C</step><octave>5</octave></pitch><duration>1</duration></note>
                </measure>
              </part>
              <part id="P2">
                <measure number="1">
                  <attributes><divisions>1</divisions></attributes>
                  <note><pitch><step>C</step><octave>3</octave></pitch><duration>1</duration></note>
                </measure>
              </part>
              <part id="P3">
                <measure number="1">
                  <attributes><divisions>1</divisions></attributes>
                  <note><pitch><step>C</step><octave>2</octave></pitch><duration>1</duration></note>
                </measure>
              </part>
            </score-partwise>
            """
        let wrapper = FileWrapper(regularFileWithContents: Data(musicXML.utf8))
        let works = try MusicXML.Importer().read(from: wrapper, as: .musicXML)
        let work = try #require(works.first)

        guard case let .standardBeat(parts, _) = work.content
        else { Issue.record("Expected standardBeat content"); return }

        #expect(parts.map(\.name) == ["Voice 1", "Cello", "Voice 3"])
    }

    @Test
    func read_multiVoicePart_producesOnePartPerVoice() throws {
        let musicXML = """
            <?xml version="1.0" encoding="UTF-8"?>
            <score-partwise version="4.0">
              <part-list>
                <score-part id="P1">
                  <part-name>Piano</part-name>
                </score-part>
              </part-list>
              <part id="P1">
                <measure number="1">
                  <attributes>
                    <divisions>2</divisions>
                    <time>
                      <beats>4</beats>
                      <beat-type>4</beat-type>
                    </time>
                  </attributes>
                  <note>
                    <pitch><step>C</step><octave>5</octave></pitch>
                    <duration>4</duration>
                    <type>half</type>
                    <voice>1</voice>
                  </note>
                  <note>
                    <chord/>
                    <pitch><step>E</step><octave>5</octave></pitch>
                    <duration>4</duration>
                    <type>half</type>
                    <voice>1</voice>
                  </note>
                  <note>
                    <pitch><step>D</step><octave>5</octave></pitch>
                    <duration>4</duration>
                    <type>half</type>
                    <voice>1</voice>
                  </note>
                  <backup>
                    <duration>8</duration>
                  </backup>
                  <note>
                    <pitch><step>C</step><octave>3</octave></pitch>
                    <duration>8</duration>
                    <type>whole</type>
                    <voice>5</voice>
                  </note>
                </measure>
              </part>
            </score-partwise>
            """
        let wrapper = FileWrapper(regularFileWithContents: Data(musicXML.utf8))
        let works = try MusicXML.Importer().read(from: wrapper, as: .musicXML)
        let work = try #require(works.first)
        let parts = try #require(standardBeatParts(of: work))

        #expect(parts.map(\.name) == ["Piano, Voice 1",
                                      "Piano, Voice 2"])

        let voice1Notes = notes(in: parts[0])

        #expect(voice1Notes.count == 3)
        #expect(voice1Notes[0].attack == .zero)
        #expect(voice1Notes[0].duration == BeatDuration(2))
        #expect(Set(voice1Notes[0..<2].map(\.pitch)) == ["C5", "E5"])
        #expect(voice1Notes[2].attack == BeatTime(2))
        #expect(voice1Notes[2].pitch == "D5")

        let voice2Notes = notes(in: parts[1])

        #expect(voice2Notes.count == 1)
        #expect(voice2Notes[0].attack == .zero)
        #expect(voice2Notes[0].duration == BeatDuration(4))
        #expect(voice2Notes[0].pitch == "C3")
    }

    @Test
    func read_noPedals_hasNoPedals() throws {
        #expect(try musicXMLImportedPedals([]).isEmpty)
    }

    @Test
    func read_noteDynamics_takesPrecedenceOverDirectionDynamics() throws {
        let musicXML = """
            <?xml version="1.0" encoding="UTF-8"?>
            <score-partwise version="4.0">
              <part-list>
                <score-part id="P1"><part-name>Piano</part-name></score-part>
              </part-list>
              <part id="P1">
                <measure number="1">
                  <attributes><divisions>1</divisions></attributes>
                  <direction><direction-type><dynamics><pp/></dynamics></direction-type></direction>
                  <note dynamics="90">
                    <pitch><step>C</step><octave>5</octave></pitch>
                    <duration>1</duration>
                    <type>quarter</type>
                  </note>
                </measure>
              </part>
            </score-partwise>
            """
        let wrapper = FileWrapper(regularFileWithContents: Data(musicXML.utf8))
        let works = try MusicXML.Importer().read(from: wrapper, as: .musicXML)
        let work = try #require(works.first)

        guard case let .standardBeat(parts, _) = work.content
        else { Issue.record("Expected standardBeat content"); return }

        //
        // The note's own `dynamics="90"` (a full default-forte velocity)
        // wins over the quiet `<pp/>` direction mark that precedes it,
        // since the note-level value is the more precise, MIDI-style
        // source.
        //
        #expect(parts.first?.dynamicMap[.zero] == Dynamic(numberValue: Number(numerator: 81, denominator: 127)))
    }

    @Test
    func read_numeralOnlyPartNamesInsideNamedGroup_combinesGroupNameWithNumerals() throws {
        // Mirrors `ActorPreludeSample.mxl`'s horns: a named brace
        // (`number="1"`) around an unnamed bracket (`number="2"`) around
        // the two numbered horn staves — the unnamed inner group must be
        // skipped in favor of the named outer one. `P3` (outside both
        // groups) keeps its own real name untouched.
        let musicXML = """
            <?xml version="1.0" encoding="UTF-8"?>
            <score-partwise version="4.0">
              <part-list>
                <part-group number="1" type="start">
                  <group-name>Horns in F</group-name>
                </part-group>
                <part-group number="2" type="start">
                  <group-symbol>bracket</group-symbol>
                </part-group>
                <score-part id="P1"><part-name>1 2</part-name></score-part>
                <score-part id="P2"><part-name>3 4</part-name></score-part>
                <part-group number="2" type="stop"/>
                <part-group number="1" type="stop"/>
                <score-part id="P3"><part-name>Tuba</part-name></score-part>
              </part-list>
              <part id="P1">
                <measure number="1">
                  <attributes><divisions>1</divisions></attributes>
                  <note><pitch><step>F</step><octave>4</octave></pitch><duration>1</duration></note>
                </measure>
              </part>
              <part id="P2">
                <measure number="1">
                  <attributes><divisions>1</divisions></attributes>
                  <note><pitch><step>C</step><octave>4</octave></pitch><duration>1</duration></note>
                </measure>
              </part>
              <part id="P3">
                <measure number="1">
                  <attributes><divisions>1</divisions></attributes>
                  <note><pitch><step>C</step><octave>2</octave></pitch><duration>1</duration></note>
                </measure>
              </part>
            </score-partwise>
            """
        let wrapper = FileWrapper(regularFileWithContents: Data(musicXML.utf8))
        let works = try MusicXML.Importer().read(from: wrapper, as: .musicXML)
        let work = try #require(works.first)

        guard case let .standardBeat(parts, _) = work.content
        else { Issue.record("Expected standardBeat content"); return }

        #expect(parts.map(\.name) == ["Horns in F (1, 2)", "Horns in F (3, 4)", "Tuba"])
    }

    @Test
    func read_scoreInstrument_populatesInstrumentTable() throws {
        let musicXML = """
            <?xml version="1.0" encoding="UTF-8"?>
            <score-partwise version="4.0">
              <part-list>
                <score-part id="P1">
                  <part-name>Violin</part-name>
                  <score-instrument id="P1-I1">
                    <instrument-name>Violin</instrument-name>
                  </score-instrument>
                </score-part>
              </part-list>
              <part id="P1">
                <measure number="1">
                  <attributes>
                    <divisions>1</divisions>
                  </attributes>
                  <note>
                    <pitch><step>C</step><octave>5</octave></pitch>
                    <duration>1</duration>
                    <type>quarter</type>
                  </note>
                </measure>
              </part>
            </score-partwise>
            """
        let wrapper = FileWrapper(regularFileWithContents: Data(musicXML.utf8))
        let works = try MusicXML.Importer().read(from: wrapper, as: .musicXML)
        let work = try #require(works.first)

        guard case let .standardBeat(parts, _) = work.content
        else { Issue.record("Expected standardBeat content"); return }

        #expect(parts.first?.instrumentTable[.zero] == Instrument("Violin"))
    }

    @Test
    func read_scorePart_populatesInstrumentExtras() throws {
        let work = try readMusicXML(header: "",
                                    scorePart: """
                                <part-name>Flute</part-name>
                                <score-instrument id="P1-I1">
                                  <instrument-name>Flauto 1</instrument-name>
                                  <instrument-abbreviation>Fl. 1</instrument-abbreviation>
                                </score-instrument>
                             """)
        let part = try #require(standardBeatParts(of: work)?.first)
        let entry = try #require(part.instrumentTable.first)

        #expect(stringValue(entry.extras, .instrumentName) == "Flauto 1")
        #expect(stringValue(entry.extras, .instrumentAbbreviation) == "Fl. 1")
    }

    @Test
    func read_scorePartMidiInstrumentPan_populatesPanMap_whenNoSoundPanEvent() throws {
        // Regression test: a `<score-part><midi-instrument><pan>0</pan>`
        // (explicit center) must still seed `panMap`, even with no `<sound>`
        // pan event anywhere in the part — `0` is a real, present value, not
        // an absent one.
        let musicXML = """
            <?xml version="1.0" encoding="UTF-8"?>
            <score-partwise version="4.0">
              <part-list>
                <score-part id="P1">
                  <part-name>Piano</part-name>
                  <midi-instrument id="P1-I1">
                    <pan>0</pan>
                  </midi-instrument>
                </score-part>
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
        let wrapper = FileWrapper(regularFileWithContents: Data(musicXML.utf8))
        let works = try MusicXML.Importer().read(from: wrapper, as: .musicXML)
        let work = try #require(works.first)

        guard case let .standardBeat(parts, _) = work.content
        else { Issue.record("Expected standardBeat content"); return }

        #expect(!(parts.first?.panMap.isEmpty ?? true))
        #expect(parts.first?.panMap[.zero] == .center)
    }

    @Test
    func read_soundAttributes_setLevels() throws {
        let pedals = try musicXMLImportedPedals([],
                                                sounds: ["<sound damper-pedal=\"yes\" soft-pedal=\"50\"/>",
                                                         "<sound damper-pedal=\"no\" sostenuto-pedal=\"yes\"/>"])

        #expect(pedals[.sustain]?.map(\.level) == [.down, .up])
        #expect(pedals[.soft]?.map(\.level) == [Pedal.Level(Number(numerator: 1, denominator: 2))])
        #expect(pedals[.sostenuto]?.map(\.time) == [1])
    }

    @Test
    func read_soundDynamics_setsLevelWithoutVelocityExtra() throws {
        let musicXML = """
            <?xml version="1.0" encoding="UTF-8"?>
            <score-partwise version="4.0">
              <part-list>
                <score-part id="P1"><part-name>Piano</part-name></score-part>
              </part-list>
              <part id="P1">
                <measure number="1">
                  <attributes><divisions>1</divisions></attributes>
                  <direction>
                    <direction-type><words>loud</words></direction-type>
                    <sound dynamics="90"/>
                  </direction>
                  <note>
                    <pitch><step>C</step><octave>5</octave></pitch>
                    <duration>1</duration>
                    <type>quarter</type>
                  </note>
                </measure>
              </part>
            </score-partwise>
            """
        let wrapper = FileWrapper(regularFileWithContents: Data(musicXML.utf8))
        let work = try #require(MusicXML.Importer().read(from: wrapper, as: .musicXML).first)
        let part = try #require(standardBeatParts(of: work)?.first)
        var dynamicVelocities: [Int?] = []

        for entry in part.dynamicMap {
            dynamicVelocities.append(intValue(entry.extras, .attackVelocity))
        }

        //
        // A `<sound>`'s velocity is exactly the one its level converts back to, so only the level
        // is kept.
        //
        #expect(part.dynamicMap[.zero] == Dynamic(numberValue: Number(numerator: 81, denominator: 127)))
        #expect(dynamicVelocities.allSatisfy { $0 == nil })
        #expect(intValue(part.noteTable.first?.extras, .attackVelocity) == nil)
    }

    @Test
    func read_soundMidiInstrumentPan_populatesPanMap() throws {
        let musicXML = """
            <?xml version="1.0" encoding="UTF-8"?>
            <score-partwise version="4.0">
              <part-list>
                <score-part id="P1">
                  <part-name>Piano</part-name>
                </score-part>
              </part-list>
              <part id="P1">
                <measure number="1">
                  <attributes>
                    <divisions>1</divisions>
                  </attributes>
                  <sound>
                    <midi-instrument id="P1-I1"><pan>-45</pan></midi-instrument>
                  </sound>
                  <note>
                    <pitch><step>C</step><octave>5</octave></pitch>
                    <duration>1</duration>
                    <type>quarter</type>
                  </note>
                </measure>
              </part>
            </score-partwise>
            """
        let wrapper = FileWrapper(regularFileWithContents: Data(musicXML.utf8))
        let works = try MusicXML.Importer().read(from: wrapper, as: .musicXML)
        let work = try #require(works.first)

        guard case let .standardBeat(parts, _) = work.content
        else { Issue.record("Expected standardBeat content"); return }

        #expect(!(parts.first?.panMap.isEmpty ?? true))
    }

    @Test
    func read_soundTempo_populatesTempoMap() throws {
        let musicXML = """
            <?xml version="1.0" encoding="UTF-8"?>
            <score-partwise version="4.0">
              <part-list>
                <score-part id="P1">
                  <part-name>Piano</part-name>
                </score-part>
              </part-list>
              <part id="P1">
                <measure number="1">
                  <attributes>
                    <divisions>1</divisions>
                  </attributes>
                  <sound tempo="144"/>
                  <note>
                    <pitch><step>C</step><octave>5</octave></pitch>
                    <duration>1</duration>
                    <type>quarter</type>
                  </note>
                </measure>
              </part>
            </score-partwise>
            """
        let wrapper = FileWrapper(regularFileWithContents: Data(musicXML.utf8))
        let works = try MusicXML.Importer().read(from: wrapper, as: .musicXML)
        let work = try #require(works.first)

        guard case let .standardBeat(_, tempoMap) = work.content
        else { Issue.record("Expected standardBeat content"); return }

        #expect(!tempoMap.isEmpty)
    }

    @Test
    func read_soundWinsOverPedalMarkInOneDirection() throws {
        let pedals = try musicXMLImportedPedals(["<pedal type=\"start\"/>"],
                                                directionSounds: ["<sound damper-pedal=\"40\"/>"])

        #expect(pedals[.sustain]?.map(\.level) == [Pedal.Level(Number(numerator: 2, denominator: 5))])
    }

    @Test
    func read_stopWithNoOpener_letsUpTheDamper() throws {
        let pedals = try musicXMLImportedPedals(["<pedal type=\"stop\"/>"])

        #expect(pedals[.sustain]?.map(\.level) == [.up])
    }

    @Test
    func read_tiedNotesWithDynamics_keepFirstVelocity() throws {
        let musicXML = """
            <?xml version="1.0" encoding="UTF-8"?>
            <score-partwise version="4.0">
              <part-list>
                <score-part id="P1"><part-name>Piano</part-name></score-part>
              </part-list>
              <part id="P1">
                <measure number="1">
                  <attributes><divisions>1</divisions></attributes>
                  <note dynamics="90">
                    <pitch><step>C</step><octave>5</octave></pitch>
                    <duration>1</duration>
                    <tie type="start"/>
                    <type>quarter</type>
                  </note>
                  <note dynamics="50">
                    <pitch><step>C</step><octave>5</octave></pitch>
                    <duration>1</duration>
                    <tie type="stop"/>
                    <type>quarter</type>
                  </note>
                </measure>
              </part>
            </score-partwise>
            """
        let wrapper = FileWrapper(regularFileWithContents: Data(musicXML.utf8))
        let work = try #require(MusicXML.Importer().read(from: wrapper, as: .musicXML).first)
        let part = try #require(standardBeatParts(of: work)?.first)
        var velocities: [Int?] = []

        for note in part.noteTable {
            velocities.append(intValue(note.extras, .attackVelocity))
        }

        // One note, attacked once: 90% of 90 is 81; the continuation's 45 doesn't replace it.
        #expect(velocities == [81])
    }

    @Test
    func read_unnamedMultiVoicePartAfterUnnamedPart_numbersVoicesByWorkPosition() throws {
        let musicXML = """
            <?xml version="1.0" encoding="UTF-8"?>
            <score-partwise version="4.0">
              <part-list>
                <score-part id="P1"><part-name></part-name></score-part>
                <score-part id="P2"><part-name></part-name></score-part>
              </part-list>
              <part id="P1">
                <measure number="1">
                  <attributes><divisions>1</divisions></attributes>
                  <note><pitch><step>C</step><octave>5</octave></pitch><duration>1</duration></note>
                </measure>
              </part>
              <part id="P2">
                <measure number="1">
                  <attributes><divisions>1</divisions></attributes>
                  <note><pitch><step>E</step><octave>4</octave></pitch><duration>1</duration><voice>1</voice></note>
                  <backup><duration>1</duration></backup>
                  <note><pitch><step>C</step><octave>3</octave></pitch><duration>1</duration><voice>5</voice></note>
                </measure>
              </part>
            </score-partwise>
            """
        let wrapper = FileWrapper(regularFileWithContents: Data(musicXML.utf8))
        let works = try MusicXML.Importer().read(from: wrapper, as: .musicXML)
        let work = try #require(works.first)
        let parts = try #require(standardBeatParts(of: work))

        // P2's voices are labeled by their position in the work, not by
        // their `<voice>` ids (1 and 5), so neither can collide with P1's
        // own positional "Voice 1".
        #expect(parts.map(\.name) == ["Voice 1", "Voice 2", "Voice 3"])
        #expect(notes(in: parts[2]).map(\.pitch) == ["C3"])
    }

    @Test
    func read_unsupportedFormat_throws() {
        let wrapper = FileWrapper(regularFileWithContents: Data())

        #expect(throws: (any Error).self) {
            try MusicXML.Importer().read(from: wrapper, as: .midi)
        }
    }

    @Test
    func read_voicesShareThePartsPedals() throws {
        let musicXML = """
            <?xml version="1.0" encoding="UTF-8"?>
            <score-partwise version="4.0">
              <part-list><score-part id="P1"><part-name>Piano</part-name></score-part></part-list>
              <part id="P1">
                <measure number="1">
                  <attributes><divisions>1</divisions></attributes>
                  <direction><direction-type><pedal type="start"/></direction-type></direction>
                  <note><pitch><step>C</step><octave>5</octave></pitch><duration>2</duration><voice>1</voice><type>half</type></note>
                  <backup><duration>2</duration></backup>
                  <note><pitch><step>C</step><octave>3</octave></pitch><duration>1</duration><voice>2</voice><type>quarter</type></note>
                  <direction><direction-type><pedal type="stop"/></direction-type></direction>
                  <note><pitch><step>D</step><octave>3</octave></pitch><duration>1</duration><voice>2</voice><type>quarter</type></note>
                </measure>
              </part>
            </score-partwise>
            """
        let parts = try musicXMLImportedParts(musicXML)

        #expect(parts.count == 2)

        for part in parts {
            #expect(part.pedals[.sustain]?.map(\.time) == [0, 1])
            #expect(part.pedals[.sustain]?.map(\.level) == [.down, .up])
        }
    }

    @Test
    func read_wedgeDiminuendo_populatesDynamicMap_asGlide() throws {
        let musicXML = """
            <?xml version="1.0" encoding="UTF-8"?>
            <score-partwise version="4.0">
              <part-list>
                <score-part id="P1"><part-name>Piano</part-name></score-part>
              </part-list>
              <part id="P1">
                <measure number="1">
                  <attributes><divisions>1</divisions></attributes>
                  <direction><direction-type><dynamics><f/></dynamics></direction-type></direction>
                  <direction><direction-type><wedge type="diminuendo" number="1"/></direction-type></direction>
                  <note>
                    <pitch><step>C</step><octave>5</octave></pitch>
                    <duration>2</duration>
                    <type>half</type>
                  </note>
                  <direction><direction-type><wedge type="stop" number="1"/></direction-type></direction>
                </measure>
              </part>
            </score-partwise>
            """
        let wrapper = FileWrapper(regularFileWithContents: Data(musicXML.utf8))
        let works = try MusicXML.Importer().read(from: wrapper, as: .musicXML)
        let work = try #require(works.first)

        guard case let .standardBeat(parts, _) = work.content
        else { Issue.record("Expected standardBeat content"); return }

        let dynamicMap = try #require(parts.first?.dynamicMap)

        //
        // The wedge opens at `f` (the notated mark just before it) and
        // shifts one level down, to `mf`, by the time it closes two beats
        // later — with a genuinely interpolated (not stepped) value partway
        // through.
        //
        #expect(dynamicMap[.zero] == .f)
        #expect(dynamicMap[BeatTime(2)] == .mf)
        #expect(dynamicMap[BeatTime(1)] != .f)
        #expect(dynamicMap[BeatTime(1)] != .mf)
    }

    @Test
    func readableFileFormats_containsMXLAndMusicXML() {
        let formats = MusicXML.Importer().readableFileFormats

        #expect(formats.contains(.mxl))
        #expect(formats.contains(.musicXML))
    }
}

// swiftlint:enable file_length
