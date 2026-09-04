// © 2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import IvorModel
import IvorTiming
import IvorTuning
import Testing
import XestiNumbers

struct MusicXMLImporterWalkerNoteTests {
}

// MARK: -

extension MusicXMLImporterWalkerNoteTests {
    @Test
    func walk_cueNote_isDroppedButStillAdvancesCursor() throws {
        let musicXML = """
            <?xml version="1.0" encoding="UTF-8"?>
            <score-partwise version="4.0">
              <part-list>
                <score-part id="P1"><part-name>P</part-name></score-part>
              </part-list>
              <part id="P1">
                <measure number="1">
                  <attributes><divisions>1</divisions></attributes>
                  <note>
                    <cue/>
                    <pitch><step>D</step><octave>4</octave></pitch>
                    <duration>2</duration>
                    <voice>1</voice>
                  </note>
                  <note>
                    <pitch><step>C</step><octave>4</octave></pitch>
                    <duration>2</duration>
                    <voice>1</voice>
                  </note>
                </measure>
              </part>
            </score-partwise>
            """
        let score = try parseMusicXMLScore(musicXML)
        let results = try MusicXML.Importer.Walker().walk(score,
                                                          order: [0])
        let voice = try #require(results.first?.part.voices.first)

        var notes: [(attack: BeatTime, pitch: Pitch)] = []

        voice.noteTable.forEach { _, attack, _, startPitch, _, _ in notes.append((attack, startPitch)) }

        // D4 never appears, but its 2-division duration still shifted C4.
        #expect(notes.count == 1)
        #expect(notes.first?.attack == BeatTime(2))
        #expect(notes.first?.pitch == "C4")
    }

    @Test
    func walk_graceNote_isDroppedFromNoteTable() throws {
        let musicXML = """
            <?xml version="1.0" encoding="UTF-8"?>
            <score-partwise version="4.0">
              <part-list>
                <score-part id="P1"><part-name>P</part-name></score-part>
              </part-list>
              <part id="P1">
                <measure number="1">
                  <attributes><divisions>1</divisions></attributes>
                  <note>
                    <grace/>
                    <pitch><step>D</step><octave>4</octave></pitch>
                    <voice>1</voice>
                  </note>
                  <note>
                    <pitch><step>C</step><octave>4</octave></pitch>
                    <duration>4</duration>
                    <voice>1</voice>
                  </note>
                </measure>
              </part>
            </score-partwise>
            """
        let score = try parseMusicXMLScore(musicXML)
        let results = try MusicXML.Importer.Walker().walk(score,
                                                          order: [0])
        let voice = try #require(results.first?.part.voices.first)

        var notes: [(attack: BeatTime, pitch: Pitch)] = []

        voice.noteTable.forEach { _, attack, _, startPitch, _, _ in notes.append((attack, startPitch)) }

        // D4 never appears, and — carrying no duration — doesn't shift C4.
        #expect(notes.count == 1)
        #expect(notes.first?.attack == .zero)
        #expect(notes.first?.pitch == "C4")
    }
}
