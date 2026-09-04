// © 2025–2026 John Gary Pusey (see LICENSE.md)

import Foundation
@testable import IvorExtern
import IvorModel
import IvorTiming
import IvorTuning
import Testing
import XestiNumbers
import XestiTools

struct MusicXMLImporterTests {
}

// MARK: -

extension MusicXMLImporterTests {
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
                    <voice>2</voice>
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
    func read_scoreInstrument_populatesInstrumentMap() throws {
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

        #expect(parts.first?.instrumentMap[.zero] == Instrument("Violin"))
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
    func read_unsupportedFormat_throws() {
        let wrapper = FileWrapper(regularFileWithContents: Data())

        #expect(throws: (any Error).self) {
            try MusicXML.Importer().read(from: wrapper, as: .midi)
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
