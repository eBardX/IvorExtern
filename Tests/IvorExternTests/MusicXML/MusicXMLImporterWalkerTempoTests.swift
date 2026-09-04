// © 2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import IvorTiming
import Testing

struct MusicXMLImporterWalkerTempoTests {
}

// MARK: -

extension MusicXMLImporterWalkerTempoTests {
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
}
