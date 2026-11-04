// © 2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import IvorModel
import IvorTiming
import IvorTuning
import Testing
import XestiNumbers

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
        #expect(intValue(voice.noteTable.first?.extras, .velocity) == 64)
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
