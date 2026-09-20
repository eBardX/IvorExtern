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

    @Test
    func walk_noteWithDynamicsAttribute_recordsVelocityExtra() throws {
        let musicXML = """
            <?xml version="1.0" encoding="UTF-8"?>
            <score-partwise version="4.0">
              <part-list>
                <score-part id="P1"><part-name>P</part-name></score-part>
              </part-list>
              <part id="P1">
                <measure number="1">
                  <attributes><divisions>1</divisions></attributes>
                  <note dynamics="71.1">
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

        // 71.1% of 90 = 63.99, rounds to 64 (a note's own `dynamics`
        // attribute converts identically to MIDI's own velocity scale,
        // per the shared-scale design note in `MusicXMLFunctions.swift`).
        #expect(voice.noteDynamicEvents.first?.velocity == 64)
    }

    @Test
    func walk_noteWithArticulationsAndSlur_attachesExtras() throws {
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
                    <pitch><step>C</step><octave>4</octave></pitch>
                    <duration>2</duration>
                    <voice>1</voice>
                    <notations>
                      <articulations><accent/></articulations>
                      <slur type="start" number="1"/>
                    </notations>
                  </note>
                  <note>
                    <pitch><step>D</step><octave>4</octave></pitch>
                    <duration>2</duration>
                    <voice>1</voice>
                    <notations>
                      <slur type="stop" number="1"/>
                    </notations>
                  </note>
                </measure>
              </part>
            </score-partwise>
            """
        let score = try parseMusicXMLScore(musicXML)
        let results = try MusicXML.Importer.Walker().walk(score,
                                                          order: [0])
        let voice = try #require(results.first?.part.voices.first)

        var flags: [(accent: Bool, slurStart: String?, slurEnd: String?)] = []

        voice.noteTable.forEach { _, _, _, _, _, extras in
            flags.append((hasFlag(extras, .accent), stringValue(extras, .slurStart), stringValue(extras, .slurEnd)))
        }

        #expect(flags.count == 2)
        #expect(flags[0].accent)
        #expect(flags[0].slurStart == "1")
        #expect(flags[1].slurEnd == "1")
    }

    @Test
    func walk_articulationOnMiddleLegOfThreeNoteTie_survivesToFinalEntry() throws {
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
                    <pitch><step>C</step><octave>4</octave></pitch>
                    <duration>1</duration>
                    <voice>1</voice>
                    <tie type="start"/>
                  </note>
                  <note>
                    <pitch><step>C</step><octave>4</octave></pitch>
                    <duration>1</duration>
                    <voice>1</voice>
                    <tie type="stop"/>
                    <tie type="start"/>
                    <notations>
                      <articulations><accent/></articulations>
                    </notations>
                  </note>
                  <note>
                    <pitch><step>C</step><octave>4</octave></pitch>
                    <duration>2</duration>
                    <voice>1</voice>
                    <tie type="stop"/>
                  </note>
                </measure>
              </part>
            </score-partwise>
            """
        let score = try parseMusicXMLScore(musicXML)
        let results = try MusicXML.Importer.Walker().walk(score,
                                                          order: [0])
        let voice = try #require(results.first?.part.voices.first)

        var notes: [(duration: BeatDuration, accent: Bool)] = []

        voice.noteTable.forEach { _, _, duration, _, _, extras in notes.append((duration, hasFlag(extras, .accent))) }

        // The whole tie chain collapses into one `NoteTable` entry summing
        // all three legs' durations — the middle leg's own `<accent/>`,
        // written on neither the first nor the last leg, still reaches it.
        #expect(notes.count == 1)
        #expect(notes[0].duration == BeatDuration(4))
        #expect(notes[0].accent)
    }
}
