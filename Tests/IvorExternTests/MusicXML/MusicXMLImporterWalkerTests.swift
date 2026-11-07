// © 2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import IvorModel
import IvorTiming
import IvorTuning
import Testing
import XestiNumbers
import XestiTools

// swiftlint:disable file_length

struct MusicXMLImporterWalkerTests {
}

// MARK: -

extension MusicXMLImporterWalkerTests {
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

        for note in voice.noteTable {
            notes.append((note.duration, hasFlag(note.extras, .accent)))
        }

        // The whole tie chain collapses into one `NoteTable` entry summing
        // all three legs' durations — the middle leg's own `<accent/>`,
        // written on neither the first nor the last leg, still reaches it.
        #expect(notes.count == 1)
        #expect(notes[0].duration == BeatDuration(4))
        #expect(notes[0].accent)
    }

    @Test
    func walk_articulations_becomeTheirExtras() throws {
        let extras = try walkedExtras(notations: """
            <articulations>
              <breath-mark/>
              <staccato/>
              <strong-accent/>
              <tenuto/>
              <other-articulation>flick</other-articulation>
              <detached-legato/>
            </articulations>
            """)

        #expect(extras?.elements.count == 5)
        #expect(hasFlag(extras, .breathMark))
        #expect(hasFlag(extras, .marcato))
        #expect(hasFlag(extras, .staccato))
        #expect(hasFlag(extras, .tenuto))
        #expect(stringValue(extras, .articulation) == "flick")
    }

    @Test
    func walk_backup_rewindsCursorForSecondVoice() throws {
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
                    <duration>4</duration>
                    <voice>1</voice>
                  </note>
                  <backup><duration>4</duration></backup>
                  <note>
                    <pitch><step>C</step><octave>3</octave></pitch>
                    <duration>2</duration>
                    <voice>2</voice>
                  </note>
                </measure>
              </part>
            </score-partwise>
            """
        let score = try parseMusicXMLScore(musicXML)
        let results = try MusicXML.Importer.Walker().walk(score,
                                                          order: [0])
        let part = try #require(results.first?.part)

        #expect(part.voices.map(\.id) == ["1", "2"])

        let firstVoice = try #require(part.voices.first { $0.id == "2" })
        var attacks: [BeatTime] = []

        for note in firstVoice.noteTable {
            attacks.append(note.attack)
        }

        #expect(attacks == [.zero])
    }

    @Test
    func walk_barlineAmongNotes_leavesCursorAlone() throws {
        let results = try walkMusicXMLMeasure("""
            <note><pitch><step>C</step><octave>4</octave></pitch><duration>1</duration><voice>1</voice></note>
            <bookmark id="b"/>
            <print/>
            <barline location="middle"/>
            <note><pitch><step>C</step><octave>4</octave></pitch><duration>1</duration><voice>1</voice></note>
            """)
        let voice = try #require(results.first?.part.voices.first)

        #expect(voice.noteTable.map(\.attack) == [.zero, BeatTime(1)])
    }

    @Test
    func walk_chordNote_sharesLeadNoteOnsetAndDuration() throws {
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
                  </note>
                  <note>
                    <chord/>
                    <pitch><step>E</step><octave>4</octave></pitch>
                    <duration>2</duration>
                  </note>
                </measure>
              </part>
            </score-partwise>
            """
        let score = try parseMusicXMLScore(musicXML)
        let results = try MusicXML.Importer.Walker().walk(score,
                                                          order: [0])
        let voice = try #require(results.first?.part.voices.first)

        var notes: [(attack: BeatTime, duration: BeatDuration)] = []

        for note in voice.noteTable {
            notes.append((note.attack, note.duration))
        }

        #expect(notes.count == 2)
        #expect(notes.allSatisfy { $0.attack == .zero && $0.duration == BeatDuration(2) })
    }

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

        for note in voice.noteTable {
            notes.append((note.attack, note.startPitch))
        }

        // D4 never appears, but its 2-division duration still shifted C4.
        #expect(notes.count == 1)
        #expect(notes.first?.attack == BeatTime(2))
        #expect(notes.first?.pitch == "C4")
    }

    @Test
    func walk_directionDynamics_recordsDirectionDynamicEvent() throws {
        let musicXML = """
            <?xml version="1.0" encoding="UTF-8"?>
            <score-partwise version="4.0">
              <part-list>
                <score-part id="P1"><part-name>P</part-name></score-part>
              </part-list>
              <part id="P1">
                <measure number="1">
                  <attributes><divisions>1</divisions></attributes>
                  <direction><direction-type><dynamics><f/></dynamics></direction-type></direction>
                  <note>
                    <pitch><step>C</step><octave>4</octave></pitch>
                    <duration>1</duration>
                  </note>
                </measure>
              </part>
            </score-partwise>
            """
        let score = try parseMusicXMLScore(musicXML)

        let results = try MusicXML.Importer.Walker().walk(score,
                                                          order: [0])

        #expect(results.first?.directionDynamicEvents.count == 1)
        #expect(results.first?.directionDynamicEvents.first?.beatTime == .zero)
        #expect(results.first?.directionDynamicEvents.first?.dynamic == .f)
        #expect(results.first?.directionDynamicEvents.first?.kind == .step)
    }

    @Test
    func walk_directionDynamics_unrecognizedMark_recordsMarkedStepAtPreviousLevel() throws {
        let musicXML = """
            <?xml version="1.0" encoding="UTF-8"?>
            <score-partwise version="4.0">
              <part-list>
                <score-part id="P1"><part-name>P</part-name></score-part>
              </part-list>
              <part id="P1">
                <measure number="1">
                  <attributes><divisions>1</divisions></attributes>
                  <direction><direction-type><dynamics><sf/></dynamics></direction-type></direction>
                  <note>
                    <pitch><step>C</step><octave>4</octave></pitch>
                    <duration>1</duration>
                  </note>
                </measure>
              </part>
            </score-partwise>
            """
        let score = try parseMusicXMLScore(musicXML)

        let results = try MusicXML.Importer.Walker().walk(score,
                                                          order: [0])

        #expect(results.first?.directionDynamicEvents.count == 1)
        #expect(results.first?.directionDynamicEvents.first?.beatTime == .zero)
        #expect(results.first?.directionDynamicEvents.first?.dynamic == .mp)
        #expect(results.first?.directionDynamicEvents.first?.kind == .step)
        #expect(results.first?.directionDynamicEvents.first?.mark == "sf")
    }

    @Test
    func walk_directionSoundDynamics_takesPrecedenceOverNotatedMark() throws {
        let musicXML = """
            <?xml version="1.0" encoding="UTF-8"?>
            <score-partwise version="4.0">
              <part-list>
                <score-part id="P1"><part-name>P</part-name></score-part>
              </part-list>
              <part id="P1">
                <measure number="1">
                  <attributes><divisions>1</divisions></attributes>
                  <direction>
                    <direction-type><dynamics><pp/></dynamics></direction-type>
                    <sound dynamics="90"/>
                  </direction>
                  <note>
                    <pitch><step>C</step><octave>4</octave></pitch>
                    <duration>1</duration>
                  </note>
                </measure>
              </part>
            </score-partwise>
            """
        let score = try parseMusicXMLScore(musicXML)

        let results = try MusicXML.Importer.Walker().walk(score,
                                                          order: [0])

        #expect(results.first?.directionDynamicEvents.count == 1)
        #expect(results.first?.directionDynamicEvents.first?.dynamic == Dynamic(numberValue: Number(numerator: 81, denominator: 127)))
    }

    @Test
    func walk_droppedChordTone_registersItsVoiceWithoutANote() throws {
        let results = try walkMusicXMLMeasure("""
            <note><pitch><step>C</step><octave>4</octave></pitch><duration>1</duration><voice>1</voice></note>
            <note>
              <grace/>
              <chord/>
              <pitch><step>E</step><octave>4</octave></pitch>
              <voice>2</voice>
            </note>
            """)
        let voices = try #require(results.first?.part.voices)

        #expect(voices.map(\.id) == ["1", "2"])
        #expect(voices.first?.noteTable.map(\.attack) == [.zero])
        #expect(voices.last?.noteTable.isEmpty == true)
    }

    @Test
    func walk_excludesPartsNotInScorePartList() throws {
        let musicXML = """
            <?xml version="1.0" encoding="UTF-8"?>
            <score-partwise version="4.0">
              <part-list>
                <score-part id="P1"><part-name>P</part-name></score-part>
              </part-list>
              <part id="P2">
                <measure number="1">
                </measure>
              </part>
            </score-partwise>
            """
        let score = try parseMusicXMLScore(musicXML)

        let results = try MusicXML.Importer.Walker().walk(score,
                                                          order: [0])

        #expect(results.isEmpty)
    }

    @Test
    func walk_fermata_becomesItsExtra() throws {
        #expect(try hasFlag(walkedExtras(notations: "<fermata/>"), .fermata))
    }

    @Test
    func walk_forward_advancesCursorAndRegistersItsVoice() throws {
        let results = try walkMusicXMLMeasure("""
            <forward><duration>2</duration><voice>2</voice></forward>
            <note><pitch><step>C</step><octave>4</octave></pitch><duration>1</duration><voice>1</voice></note>
            """)
        let voices = try #require(results.first?.part.voices)

        #expect(voices.map(\.id) == ["1", "2"])
        #expect(voices.first?.noteTable.map(\.attack) == [BeatTime(2)])
    }

    @Test
    func walk_graceCueNote_isDroppedAndAdvancesNothing() throws {
        let results = try walkMusicXMLMeasure("""
            <note>
              <grace/>
              <cue/>
              <pitch><step>D</step><octave>4</octave></pitch>
              <voice>1</voice>
            </note>
            <note><pitch><step>C</step><octave>4</octave></pitch><duration>1</duration><voice>1</voice></note>
            """)
        let voice = try #require(results.first?.part.voices.first)

        #expect(voice.noteTable.map(\.attack) == [.zero])
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

        for note in voice.noteTable {
            notes.append((note.attack, note.startPitch))
        }

        // D4 never appears, and — carrying no duration — doesn't shift C4.
        #expect(notes.count == 1)
        #expect(notes.first?.attack == .zero)
        #expect(notes.first?.pitch == "C4")
    }

    @Test
    func walk_measureRepeat_attributesInACoveredMeasure_stillApply() throws {
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
                    <duration>4</duration>
                  </note>
                </measure>
                <measure number="2">
                  <attributes>
                    <divisions>2</divisions>
                    <measure-style><measure-repeat type="start">1</measure-repeat></measure-style>
                  </attributes>
                </measure>
                <measure number="3">
                  <attributes>
                    <measure-style><measure-repeat type="stop"/></measure-style>
                  </attributes>
                  <note>
                    <pitch><step>C</step><octave>4</octave></pitch>
                    <duration>1</duration>
                  </note>
                </measure>
              </part>
            </score-partwise>
            """
        let score = try parseMusicXMLScore(musicXML)
        let results = try MusicXML.Importer.Walker().walk(score,
                                                          order: [0, 1, 2])
        let voice = try #require(results.first?.part.voices.first)

        // The repeated note keeps the divisions it was written in; the
        // change applies from the measure after.
        #expect(voice.noteTable.map(\.attack) == [.zero, BeatTime(4), BeatTime(8)])
        #expect(voice.noteTable.map(\.duration) == [BeatDuration(4),
                                                    BeatDuration(4),
                                                    BeatDuration(Number(numerator: 1, denominator: 2))])
    }

    @Test
    func walk_metronomeMark_recordsTempoEvent() throws {
        let musicXML = """
            <?xml version="1.0" encoding="UTF-8"?>
            <score-partwise version="4.0">
              <part-list>
                <score-part id="P1"><part-name>P</part-name></score-part>
              </part-list>
              <part id="P1">
                <measure number="1">
                  <attributes><divisions>1</divisions></attributes>
                  <direction>
                    <direction-type>
                      <metronome>
                        <beat-unit>quarter</beat-unit>
                        <per-minute>96</per-minute>
                      </metronome>
                    </direction-type>
                  </direction>
                  <note>
                    <pitch><step>C</step><octave>4</octave></pitch>
                    <duration>1</duration>
                  </note>
                </measure>
              </part>
            </score-partwise>
            """
        let score = try parseMusicXMLScore(musicXML)

        let results = try MusicXML.Importer.Walker().walk(score,
                                                          order: [0])

        #expect(results.first?.tempoEvents.count == 1)
        #expect(results.first?.tempoEvents.first?.beatTime == .zero)
        #expect(results.first?.tempoEvents.first?.tempo == Tempo(uintValue: 96))
    }

    @Test(arguments: ["inverted-mordent", "mordent"])
    func walk_mordentOrnaments_becomeMordentExtra(element: String) throws {
        #expect(try hasFlag(walkedExtras(notations: "<ornaments><\(element)/></ornaments>"), .mordent))
    }

    @Test
    func walk_multipleRest_attributesInItsOwnMeasure_stillApply() throws {
        let musicXML = """
            <?xml version="1.0" encoding="UTF-8"?>
            <score-partwise version="4.0">
              <part-list>
                <score-part id="P1"><part-name>P</part-name></score-part>
              </part-list>
              <part id="P1">
                <measure number="1">
                  <attributes>
                    <divisions>2</divisions>
                    <time><beats>4</beats><beat-type>4</beat-type></time>
                    <measure-style><multiple-rest>2</multiple-rest></measure-style>
                  </attributes>
                </measure>
                <measure number="2"/>
                <measure number="3">
                  <note>
                    <pitch><step>C</step><octave>4</octave></pitch>
                    <duration>1</duration>
                  </note>
                </measure>
              </part>
            </score-partwise>
            """
        let score = try parseMusicXMLScore(musicXML)
        let results = try MusicXML.Importer.Walker().walk(score,
                                                          order: [0, 1, 2])
        let voice = try #require(results.first?.part.voices.first)

        #expect(voice.noteTable.map(\.attack) == [BeatTime(8)])
        #expect(voice.noteTable.map(\.duration) == [BeatDuration(Number(numerator: 1, denominator: 2))])
    }

    @Test
    func walk_multipleRest_withoutTime_throws() throws {
        let score = try parseMusicXMLScore(multipleRestMusicXML(time: ""))

        #expect(throws: MusicXML.Error.self) {
            _ = try MusicXML.Importer.Walker().walk(score,
                                                    order: [0, 1, 2, 3])
        }
    }

    @Test
    func walk_multipleRest_withTime_advancesOverItsEmptyMeasures() throws {
        let time = "<time><beats>4</beats><beat-type>4</beat-type></time>"
        let score = try parseMusicXMLScore(multipleRestMusicXML(time: time))
        let results = try MusicXML.Importer.Walker().walk(score,
                                                          order: [0, 1, 2, 3])
        let voice = try #require(results.first?.part.voices.first)

        #expect(voice.noteTable.map(\.attack) == [.zero, BeatTime(12)])
    }

    @Test
    func walk_noteDynamics_recordsNoteDynamicEventOnItsVoice() throws {
        let musicXML = """
            <?xml version="1.0" encoding="UTF-8"?>
            <score-partwise version="4.0">
              <part-list>
                <score-part id="P1"><part-name>P</part-name></score-part>
              </part-list>
              <part id="P1">
                <measure number="1">
                  <attributes><divisions>1</divisions></attributes>
                  <note dynamics="45">
                    <pitch><step>C</step><octave>4</octave></pitch>
                    <duration>1</duration>
                  </note>
                </measure>
              </part>
            </score-partwise>
            """
        let score = try parseMusicXMLScore(musicXML)

        let results = try MusicXML.Importer.Walker().walk(score,
                                                          order: [0])
        let voice = try #require(results.first?.part.voices.first)

        #expect(voice.noteDynamicEvents.count == 1)
        #expect(voice.noteDynamicEvents.first?.beatTime == .zero)
        #expect(voice.noteDynamicEvents.first?.dynamic == Dynamic(numberValue: Number(numerator: 81, denominator: 254)))
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

        for note in voice.noteTable {
            flags.append((hasFlag(note.extras, .accent), stringValue(note.extras, .slurStart), stringValue(note.extras, .slurEnd)))
        }

        #expect(flags.count == 2)
        #expect(flags[0].accent)
        #expect(flags[0].slurStart == "1")
        #expect(flags[1].slurEnd == "1")
    }

    @Test
    func walk_noteWithDynamicsAttribute_recordsAttackVelocityExtra() throws {
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
        #expect(intValue(voice.noteTable.first?.extras, .attackVelocity) == 64)
    }

    @Test
    func walk_noteWithEndDynamicsAttribute_recordsReleaseVelocityExtra() throws {
        let musicXML = """
            <?xml version="1.0" encoding="UTF-8"?>
            <score-partwise version="4.0">
              <part-list>
                <score-part id="P1"><part-name>P</part-name></score-part>
              </part-list>
              <part id="P1">
                <measure number="1">
                  <attributes><divisions>1</divisions></attributes>
                  <note end-dynamics="44.44">
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

        // 44.44% of 90 = 39.996, rounds to 40, on the same scale as a
        // note's own `dynamics` attribute.
        #expect(intValue(voice.noteTable.first?.extras, .releaseVelocity) == 40)
        #expect(intValue(voice.noteTable.first?.extras, .attackVelocity) == nil)
    }

    @Test
    func walk_otherOrnament_becomesArticulationExtra() throws {
        let extras = try walkedExtras(notations: "<ornaments><other-ornament>flip</other-ornament></ornaments>")

        #expect(stringValue(extras, .articulation) == "flip")
    }

    @Test
    func walk_slurContinue_attachesNoExtra() throws {
        #expect(try walkedExtras(notations: #"<slur type="continue"/>"#) == nil)
    }

    @Test
    func walk_snapPizzicato_becomesPizzicatoExtra() throws {
        #expect(try hasFlag(walkedExtras(notations: "<technical><snap-pizzicato/></technical>"), .pizzicato))
    }

    @Test
    func walk_soundDynamicsOutsideADirection_recordsStepAtTheCursor() throws {
        let results = try walkMusicXMLMeasure("""
            <note><pitch><step>C</step><octave>4</octave></pitch><duration>1</duration><voice>1</voice></note>
            <sound dynamics="80"/>
            """)
        let events = try #require(results.first?.directionDynamicEvents)

        #expect(events.count == 1)
        #expect(events.first?.beatTime == BeatTime(1))
        #expect(events.first?.kind == .step)
    }

    @Test
    func walk_soundMidiInstrumentPan_recordsPanEvent() throws {
        let musicXML = """
            <?xml version="1.0" encoding="UTF-8"?>
            <score-partwise version="4.0">
              <part-list>
                <score-part id="P1"><part-name>P</part-name></score-part>
              </part-list>
              <part id="P1">
                <measure number="1">
                  <attributes><divisions>1</divisions></attributes>
                  <sound>
                    <midi-instrument id="P1-I1"><pan>-45</pan></midi-instrument>
                  </sound>
                  <note>
                    <pitch><step>C</step><octave>4</octave></pitch>
                    <duration>1</duration>
                  </note>
                </measure>
              </part>
            </score-partwise>
            """
        let score = try parseMusicXMLScore(musicXML)

        let results = try MusicXML.Importer.Walker().walk(score,
                                                          order: [0])

        #expect(results.first?.panEvents.count == 1)
        #expect(results.first?.panEvents.first?.beatTime == .zero)
        #expect(results.first?.panEvents.first?.pan == Pan(horizontal: -45))
    }

    @Test
    func walk_soundTempo_recordsTempoEvent() throws {
        let musicXML = """
            <?xml version="1.0" encoding="UTF-8"?>
            <score-partwise version="4.0">
              <part-list>
                <score-part id="P1"><part-name>P</part-name></score-part>
              </part-list>
              <part id="P1">
                <measure number="1">
                  <attributes><divisions>1</divisions></attributes>
                  <sound tempo="120"/>
                  <note>
                    <pitch><step>C</step><octave>4</octave></pitch>
                    <duration>1</duration>
                  </note>
                </measure>
              </part>
            </score-partwise>
            """
        let score = try parseMusicXMLScore(musicXML)

        let results = try MusicXML.Importer.Walker().walk(score,
                                                          order: [0])

        #expect(results.first?.tempoEvents.count == 1)
        #expect(results.first?.tempoEvents.first?.beatTime == .zero)
    }

    @Test
    func walk_soundTempo_takesPrecedenceOverMetronomeMark() throws {
        let musicXML = """
            <?xml version="1.0" encoding="UTF-8"?>
            <score-partwise version="4.0">
              <part-list>
                <score-part id="P1"><part-name>P</part-name></score-part>
              </part-list>
              <part id="P1">
                <measure number="1">
                  <attributes><divisions>1</divisions></attributes>
                  <direction>
                    <direction-type>
                      <metronome>
                        <beat-unit>quarter</beat-unit>
                        <per-minute>96</per-minute>
                      </metronome>
                    </direction-type>
                    <sound tempo="144"/>
                  </direction>
                  <note>
                    <pitch><step>C</step><octave>4</octave></pitch>
                    <duration>1</duration>
                  </note>
                </measure>
              </part>
            </score-partwise>
            """
        let score = try parseMusicXMLScore(musicXML)

        let results = try MusicXML.Importer.Walker().walk(score,
                                                          order: [0])

        #expect(results.first?.tempoEvents.count == 1)
        #expect(results.first?.tempoEvents.first?.tempo == Tempo(uintValue: 144))
    }

    @Test
    func walk_technical_becomesItsExtras() throws {
        let extras = try walkedExtras(notations: """
            <technical>
              <up-bow/>
              <down-bow/>
              <harmonic/>
              <fingering>3</fingering>
              <other-technical>tap</other-technical>
              <stopped/>
            </technical>
            """)

        #expect(extras?.elements.count == 5)
        #expect(hasFlag(extras, .downBow))
        #expect(hasFlag(extras, .harmonic))
        #expect(hasFlag(extras, .upBow))
        #expect(stringValue(extras, .articulation) == "tap")
        #expect(stringValue(extras, .fingering) == "3")
    }

    @Test
    func walk_tiedNotes_combineIntoOneNote() throws {
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
                    <tie type="start"/>
                  </note>
                  <note>
                    <pitch><step>C</step><octave>4</octave></pitch>
                    <duration>1</duration>
                    <tie type="stop"/>
                  </note>
                </measure>
              </part>
            </score-partwise>
            """
        let score = try parseMusicXMLScore(musicXML)
        let voice = try #require(try MusicXML.Importer.Walker().walk(score,
                                                                     order: [0]).first?.part.voices.first)

        var notes: [(attack: BeatTime, duration: BeatDuration)] = []

        for note in voice.noteTable {
            notes.append((note.attack, note.duration))
        }

        #expect(notes.count == 1)
        #expect(notes.first?.attack == .zero)
        #expect(notes.first?.duration == BeatDuration(2))
    }

    @Test
    func walk_tiedNotes_keepFirstAttackAndLastReleaseVelocity() throws {
        let musicXML = """
            <?xml version="1.0" encoding="UTF-8"?>
            <score-partwise version="4.0">
              <part-list>
                <score-part id="P1"><part-name>P</part-name></score-part>
              </part-list>
              <part id="P1">
                <measure number="1">
                  <attributes><divisions>1</divisions></attributes>
                  <note dynamics="100" end-dynamics="50">
                    <pitch><step>C</step><octave>4</octave></pitch>
                    <duration>1</duration>
                    <tie type="start"/>
                  </note>
                  <note dynamics="50" end-dynamics="100">
                    <pitch><step>C</step><octave>4</octave></pitch>
                    <duration>1</duration>
                    <tie type="stop"/>
                    <tie type="start"/>
                  </note>
                  <note dynamics="20" end-dynamics="20">
                    <pitch><step>C</step><octave>4</octave></pitch>
                    <duration>1</duration>
                    <tie type="stop"/>
                  </note>
                </measure>
              </part>
            </score-partwise>
            """
        let score = try parseMusicXMLScore(musicXML)
        let voice = try #require(try MusicXML.Importer.Walker().walk(score,
                                                                     order: [0]).first?.part.voices.first)
        let extras = voice.noteTable.first?.extras

        // 100% of 90 = 90 from the first note; 20% of 90 = 18 from the last.
        #expect(intValue(extras, .attackVelocity) == 90)
        #expect(intValue(extras, .releaseVelocity) == 18)
    }

    @Test
    func walk_tieNeverStopped_keepsItsNoteAtTheEnd() throws {
        let results = try walkMusicXMLMeasure("""
            <note>
              <pitch><step>C</step><octave>4</octave></pitch>
              <duration>2</duration>
              <tie type="start"/>
            </note>
            """)
        let voice = try #require(results.first?.part.voices.first)

        #expect(voice.noteTable.map(\.duration) == [BeatDuration(2)])
    }

    @Test
    func walk_transpose_appliesToSoundingPitch() throws {
        let musicXML = """
            <?xml version="1.0" encoding="UTF-8"?>
            <score-partwise version="4.0">
              <part-list>
                <score-part id="P1"><part-name>P</part-name></score-part>
              </part-list>
              <part id="P1">
                <measure number="1">
                  <attributes>
                    <divisions>1</divisions>
                    <transpose>
                      <chromatic>-2</chromatic>
                    </transpose>
                  </attributes>
                  <note>
                    <pitch><step>C</step><octave>5</octave></pitch>
                    <duration>1</duration>
                  </note>
                </measure>
              </part>
            </score-partwise>
            """
        let score = try parseMusicXMLScore(musicXML)
        let voice = try #require(try MusicXML.Importer.Walker().walk(score,
                                                                     order: [0]).first?.part.voices.first)

        var pitches: [Pitch] = []

        for note in voice.noteTable {
            pitches.append(note.startPitch)
        }

        #expect(pitches.first?.pitchClass.letter == .a)
        #expect(pitches.first?.pitchClass.accidental == .sharp)
        #expect(pitches.first?.octave == Pitch.Octave(intValue: 4))
    }

    @Test
    func walk_trillMark_becomesTrillExtra() throws {
        #expect(try hasFlag(walkedExtras(notations: "<ornaments><trill-mark/></ornaments>"), .trill))
    }

    @Test(arguments: ["delayed-inverted-turn", "delayed-turn", "inverted-turn", "turn"])
    func walk_turnOrnaments_becomeTurnExtra(element: String) throws {
        #expect(try hasFlag(walkedExtras(notations: "<ornaments><\(element)/></ornaments>"), .turn))
    }

    @Test
    func walk_unbalancedBackup_throws() {
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
                  </note>
                  <backup><duration>4</duration></backup>
                </measure>
              </part>
            </score-partwise>
            """

        #expect(throws: (any Error).self) {
            let score = try parseMusicXMLScore(musicXML)

            _ = try MusicXML.Importer.Walker().walk(score,
                                                    order: [0])
        }
    }

    @Test
    func walk_unlistedOrnament_attachesNoExtra() throws {
        #expect(try walkedExtras(notations: "<ornaments><shake/></ornaments>") == nil)
    }

    @Test
    func walk_unpitchedNotes_advanceOnceAndLeaveNoNote() throws {
        let results = try walkMusicXMLMeasure("""
            <note>
              <unpitched><display-step>C</display-step><display-octave>4</display-octave></unpitched>
              <duration>2</duration>
              <voice>1</voice>
            </note>
            <note>
              <chord/>
              <unpitched><display-step>E</display-step><display-octave>4</display-octave></unpitched>
              <duration>2</duration>
              <voice>1</voice>
            </note>
            <note><pitch><step>C</step><octave>4</octave></pitch><duration>1</duration><voice>1</voice></note>
            """)
        let voice = try #require(results.first?.part.voices.first)

        #expect(voice.noteTable.map(\.attack) == [BeatTime(2)])
    }

    @Test
    func walk_voiceDeclaredOutOfOrder_sortsPartVoicesByID() throws {
        // Voice "2"'s only note is written before voice "1"'s — MusicXML
        // declares no voice order anywhere, so nothing stops an encoder
        // from doing this — and `part.voices` should still come back
        // sorted by ID rather than in this encounter order.
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
                    <pitch><step>C</step><octave>3</octave></pitch>
                    <duration>4</duration>
                    <voice>2</voice>
                  </note>
                  <backup><duration>4</duration></backup>
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
        let part = try #require(results.first?.part)

        #expect(part.voices.map(\.id) == ["1", "2"])
    }

    @Test
    func walk_wedgeContinue_leavesTheOpenWedgeAlone() throws {
        let results = try walkMusicXMLMeasure("""
            <direction><direction-type><wedge type="crescendo" number="1"/></direction-type></direction>
            <note><pitch><step>C</step><octave>4</octave></pitch><duration>1</duration><voice>1</voice></note>
            <direction><direction-type><wedge type="continue" number="1"/></direction-type></direction>
            <note><pitch><step>C</step><octave>4</octave></pitch><duration>1</duration><voice>1</voice></note>
            <direction><direction-type><wedge type="stop" number="1"/></direction-type></direction>
            """)
        let events = try #require(results.first?.directionDynamicEvents)

        #expect(events.map(\.beatTime) == [.zero, BeatTime(2)])
    }

    @Test
    func walk_wedgeCrescendo_recordsRampBoundaryEvents() throws {
        let musicXML = """
            <?xml version="1.0" encoding="UTF-8"?>
            <score-partwise version="4.0">
              <part-list>
                <score-part id="P1"><part-name>P</part-name></score-part>
              </part-list>
              <part id="P1">
                <measure number="1">
                  <attributes><divisions>1</divisions></attributes>
                  <direction><direction-type><wedge type="crescendo" number="1"/></direction-type></direction>
                  <note>
                    <pitch><step>C</step><octave>4</octave></pitch>
                    <duration>1</duration>
                  </note>
                  <direction><direction-type><wedge type="stop" number="1"/></direction-type></direction>
                </measure>
              </part>
            </score-partwise>
            """
        let score = try parseMusicXMLScore(musicXML)

        let results = try MusicXML.Importer.Walker().walk(score,
                                                          order: [0])
        let events = results.first?.directionDynamicEvents ?? []

        #expect(events.count == 2)
        #expect(events.allSatisfy { $0.kind == .rampBoundary })
        #expect(events.first?.beatTime == .zero)
        #expect(events.first?.dynamic == .mp)
        #expect(events.last?.beatTime == BeatTime(1))
        #expect(events.last?.dynamic == .mf)
    }
}

// swiftlint:enable file_length
