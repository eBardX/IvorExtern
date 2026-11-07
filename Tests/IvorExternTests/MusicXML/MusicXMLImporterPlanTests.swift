// © 2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import Testing

struct MusicXMLImporterPlanTests {
    private let backward = #"<barline location="right"><repeat direction="backward"/></barline>"#
    private let forward = #"<barline location="left"><repeat direction="forward"/></barline>"#
}

// MARK: -

extension MusicXMLImporterPlanTests {
    @Test
    func init_barlineSegnoAndCoda_serveAsJumpTargets() throws {
        let score = try parseMusicXMLScore("""
            <?xml version="1.0" encoding="UTF-8"?>
            <score-partwise version="4.0">
              <part-list>
                <score-part id="P1"><part-name>P</part-name></score-part>
              </part-list>
              <part id="P1">
                <measure number="1"></measure>
                <measure number="2"><barline location="left"><segno/></barline></measure>
                <measure number="3"><sound tocoda="c"/></measure>
                <measure number="4"><sound dalsegno="s"/></measure>
                <measure number="5"></measure>
                <measure number="6"><barline location="left"><coda/></barline></measure>
              </part>
            </score-partwise>
            """)

        let plan = try MusicXML.Importer.Plan(score)

        #expect(plan.order == [0, 1, 2, 3, 1, 2, 5])
    }

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
    func init_daCapoOverEndings_takesOnlyTheLastEnding() throws {
        let order = try plannedOrder([forward,
                                      firstEnding(1),
                                      lastEnding(2) + #"<sound dacapo="yes"/>"#])

        #expect(order == [0, 1, 0, 2, 0, 2])
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
    func init_dalSegnoOverMultiMeasureEndings_skipsEveryEarlierEnding() throws {
        let order = try plannedOrder([forward + #"<sound segno="s"/>"#,
                                      #"<barline location="left"><ending number="1" type="start"/></barline>"#,
                                      #"<barline location="right"><ending number="1" type="stop"/><repeat direction="backward"/></barline>"#,
                                      lastEnding(2) + #"<sound dalsegno="s"/>"#])

        #expect(order == [0, 1, 2, 0, 3, 0, 3])
    }

    @Test
    func init_endingsBeyondTwo_playOnTheirOwnPasses() throws {
        let order = try plannedOrder([forward,
                                      firstEnding(1),
                                      firstEnding(2),
                                      lastEnding(3)])

        #expect(order == [0, 1, 0, 2, 0, 3])
    }

    @Test
    func init_explicitTimes_winsOverFewerEndings() throws {
        let start = #"<barline location="left"><ending number="1, 2" type="start"/></barline>"#
        let stop = #"<ending number="1, 2" type="stop"/><repeat direction="backward" times="3"/>"#
        let order = try plannedOrder([forward,
                                      start + #"<barline location="right">\#(stop)</barline>"#,
                                      lastEnding(3)])

        #expect(order == [0, 1, 0, 1, 0, 2])
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
    func init_repeatAfterEndings_startsItsOwnPasses() throws {
        let order = try plannedOrder([forward,
                                      firstEnding(1),
                                      lastEnding(2),
                                      forward,
                                      backward])

        #expect(order == [0, 1, 0, 2, 3, 4, 3, 4])
    }

    @Test
    func init_sectionAfterEndings_playsItsOwnEndings() throws {
        let order = try plannedOrder([forward,
                                      firstEnding(1),
                                      lastEnding(2),
                                      forward,
                                      firstEnding(1),
                                      lastEnding(2)])

        #expect(order == [0, 1, 0, 2, 3, 4, 3, 5])
    }

    @Test
    func init_sectionOpeningOnItsFirstEnding_playsIt() throws {
        let order = try plannedOrder([forward,
                                      firstEnding(1),
                                      lastEnding(2),
                                      forward + firstEnding(1),
                                      lastEnding(2)])

        #expect(order == [0, 1, 0, 2, 3, 4])
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

    @Test
    func init_toCoda_jumpsToTheNamedCoda() throws {
        let score = try parseMusicXMLScore("""
            <?xml version="1.0" encoding="UTF-8"?>
            <score-partwise version="4.0">
              <part-list>
                <score-part id="P1"><part-name>P</part-name></score-part>
              </part-list>
              <part id="P1">
                <measure number="1"><sound tocoda="c"/></measure>
                <measure number="2"><sound dacapo="yes"/></measure>
                <measure number="3"></measure>
                <measure number="4"><sound coda="c"/></measure>
              </part>
            </score-partwise>
            """)

        let plan = try MusicXML.Importer.Plan(score)

        #expect(plan.order == [0, 1, 0, 3])
    }

    @Test
    func init_toCoda_unmatchedName_jumpsToTheFirstCoda() throws {
        let score = try parseMusicXMLScore("""
            <?xml version="1.0" encoding="UTF-8"?>
            <score-partwise version="4.0">
              <part-list>
                <score-part id="P1"><part-name>P</part-name></score-part>
              </part-list>
              <part id="P1">
                <measure number="1"><sound tocoda="other"/></measure>
                <measure number="2"><sound dacapo="yes"/></measure>
                <measure number="3"></measure>
                <measure number="4"><sound coda="c"/></measure>
              </part>
            </score-partwise>
            """)

        let plan = try MusicXML.Importer.Plan(score)

        #expect(plan.order == [0, 1, 0, 3])
    }
}
