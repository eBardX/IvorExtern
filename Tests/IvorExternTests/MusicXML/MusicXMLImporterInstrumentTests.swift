// © 2025–2026 John Gary Pusey (see LICENSE.md)

import Foundation
@testable import IvorExtern
import IvorModel
import IvorTiming
import IvorTuning
import Testing
import XestiNumbers
import XestiTools

struct MusicXMLImporterInstrumentTests {
}

// MARK: -

extension MusicXMLImporterInstrumentTests {
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

        var foundChannel: Int?
        var foundBank: Int?

        parts.first?.instrumentMap.forEach { _, _, _, extras in
            foundChannel = intValue(extras, .midiChannel)
            foundBank = intValue(extras, .midiBank)
        }

        #expect(foundChannel == 3)
        #expect(foundBank == 131)
    }

    @Test
    func read_midiInstrumentChannelOnlyNoNameOrProgram_populatesVanillaInstrumentWithChannelExtra() throws {
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

        #expect(parts.first?.instrumentMap[.zero] == Instrument.vanilla)

        var foundChannel: Int?

        parts.first?.instrumentMap.forEach { _, _, _, extras in
            foundChannel = intValue(extras, .midiChannel)
        }

        #expect(foundChannel == 5)
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
}
