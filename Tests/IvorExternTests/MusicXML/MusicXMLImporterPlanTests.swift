// © 2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import Testing

struct MusicXMLImporterPlanTests {
}

// MARK: -

extension MusicXMLImporterPlanTests {
    @Test
    func init_daCapoAlFine_repeatsFromStartThenStopsAtFine() throws {
        let musicXML = """
            <?xml version="1.0" encoding="UTF-8"?>
            <score-partwise version="4.0">
              <part-list>
                <score-part id="P1"><part-name>P</part-name></score-part>
              </part-list>
              <part id="P1">
                <measure number="1"></measure>
                <measure number="2">
                  <sound fine="yes"/>
                </measure>
                <measure number="3">
                  <sound dacapo="yes"/>
                </measure>
              </part>
            </score-partwise>
            """
        let score = try parseMusicXMLScore(musicXML)

        let plan = try MusicXML.Importer.Plan(score)

        #expect(plan.order == [0, 1, 2, 0, 1])
    }

    @Test
    func init_dalSegno_jumpsToSegnoMarker() throws {
        let musicXML = """
            <?xml version="1.0" encoding="UTF-8"?>
            <score-partwise version="4.0">
              <part-list>
                <score-part id="P1"><part-name>P</part-name></score-part>
              </part-list>
              <part id="P1">
                <measure number="1">
                  <sound segno="Segno"/>
                </measure>
                <measure number="2"></measure>
                <measure number="3">
                  <sound dalsegno="Segno"/>
                </measure>
              </part>
            </score-partwise>
            """
        let score = try parseMusicXMLScore(musicXML)

        let plan = try MusicXML.Importer.Plan(score)

        #expect(plan.order == [0, 1, 2, 0, 1, 2])
    }

    @Test
    func init_firstAndSecondEndings_playsEachOnlyOnItsOwnPass() throws {
        let musicXML = """
            <?xml version="1.0" encoding="UTF-8"?>
            <score-partwise version="4.0">
              <part-list>
                <score-part id="P1"><part-name>P</part-name></score-part>
              </part-list>
              <part id="P1">
                <measure number="1">
                  <barline location="left">
                    <repeat direction="forward"/>
                  </barline>
                </measure>
                <measure number="2">
                  <barline location="left">
                    <ending number="1" type="start"/>
                  </barline>
                  <barline location="right">
                    <ending number="1" type="stop"/>
                    <repeat direction="backward"/>
                  </barline>
                </measure>
                <measure number="3">
                  <barline location="left">
                    <ending number="2" type="start"/>
                  </barline>
                  <barline location="right">
                    <ending number="2" type="discontinue"/>
                  </barline>
                </measure>
                <measure number="4"></measure>
              </part>
            </score-partwise>
            """
        let score = try parseMusicXMLScore(musicXML)

        let plan = try MusicXML.Importer.Plan(score)

        #expect(plan.order == [0, 1, 0, 2, 3])
    }

    @Test
    func init_noMarkers_playsEveryMeasureOnceInOrder() throws {
        let musicXML = """
            <?xml version="1.0" encoding="UTF-8"?>
            <score-partwise version="4.0">
              <part-list>
                <score-part id="P1"><part-name>P</part-name></score-part>
              </part-list>
              <part id="P1">
                <measure number="1"></measure>
                <measure number="2"></measure>
                <measure number="3"></measure>
              </part>
            </score-partwise>
            """
        let score = try parseMusicXMLScore(musicXML)

        let plan = try MusicXML.Importer.Plan(score)

        #expect(plan.order == [0, 1, 2])
    }

    @Test
    func init_simpleRepeat_repeatsSpanTwiceByDefault() throws {
        let musicXML = """
            <?xml version="1.0" encoding="UTF-8"?>
            <score-partwise version="4.0">
              <part-list>
                <score-part id="P1"><part-name>P</part-name></score-part>
              </part-list>
              <part id="P1">
                <measure number="1">
                  <barline location="left">
                    <repeat direction="forward"/>
                  </barline>
                </measure>
                <measure number="2">
                  <barline location="right">
                    <repeat direction="backward"/>
                  </barline>
                </measure>
              </part>
            </score-partwise>
            """
        let score = try parseMusicXMLScore(musicXML)

        let plan = try MusicXML.Importer.Plan(score)

        #expect(plan.order == [0, 1, 0, 1])
    }

    @Test
    func init_simpleRepeatWithExplicitTimes_repeatsSpanThatManyTimes() throws {
        let musicXML = """
            <?xml version="1.0" encoding="UTF-8"?>
            <score-partwise version="4.0">
              <part-list>
                <score-part id="P1"><part-name>P</part-name></score-part>
              </part-list>
              <part id="P1">
                <measure number="1">
                  <barline location="left">
                    <repeat direction="forward"/>
                  </barline>
                </measure>
                <measure number="2">
                  <barline location="right">
                    <repeat direction="backward" times="3"/>
                  </barline>
                </measure>
              </part>
            </score-partwise>
            """
        let score = try parseMusicXMLScore(musicXML)

        let plan = try MusicXML.Importer.Plan(score)

        #expect(plan.order == [0, 1, 0, 1, 0, 1])
    }
}
