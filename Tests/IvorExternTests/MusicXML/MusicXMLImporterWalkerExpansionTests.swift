// © 2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import IvorMusicXML
import Testing

struct MusicXMLImporterWalkerExpansionTests {
}

// MARK: -

extension MusicXMLImporterWalkerExpansionTests {
    @Test
    func plan_measureRepeat_expandsEmptyCoveredMeasuresFromThePattern() throws {
        let musicXML = """
            <?xml version="1.0" encoding="UTF-8"?>
            <score-partwise version="4.0">
              <part-list>
                <score-part id="P1"><part-name>P</part-name></score-part>
              </part-list>
              <part id="P1">
                <measure number="1">
                  <note><pitch><step>C</step><octave>4</octave></pitch><duration>4</duration></note>
                </measure>
                <measure number="2">
                  <note><pitch><step>D</step><octave>4</octave></pitch><duration>4</duration></note>
                </measure>
                <measure number="3">
                  <attributes>
                    <measure-style>
                      <measure-repeat type="start">2</measure-repeat>
                    </measure-style>
                  </attributes>
                </measure>
                <measure number="4">
                </measure>
                <measure number="5">
                  <attributes>
                    <measure-style>
                      <measure-repeat type="stop">2</measure-repeat>
                    </measure-style>
                  </attributes>
                </measure>
              </part>
            </score-partwise>
            """
        let score = try parseMusicXMLScore(musicXML)
        let part = try #require(score.parts.first)
        var expansion = MusicXML.Importer.Walker.Expansion()

        let plans = part.measures.enumerated().map { index, measure in
            expansion.plan(measure, at: index, in: part)
        }

        guard case let .items(patternMeasure3) = plans[2],
              case let .items(patternMeasure4) = plans[3],
              case let .items(measure5) = plans[4]
        else {
            Issue.record("expected .items for every planned measure")
            return
        }

        #expect(patternMeasure3 == part.measures[0].items)
        #expect(patternMeasure4 == part.measures[1].items)
        #expect(measure5 == part.measures[4].items)
    }

    @Test
    func plan_multipleRest_coveredMeasureAlreadyHasNotes_returnsItemsAsWritten() throws {
        let musicXML = """
            <?xml version="1.0" encoding="UTF-8"?>
            <score-partwise version="4.0">
              <part-list>
                <score-part id="P1"><part-name>P</part-name></score-part>
              </part-list>
              <part id="P1">
                <measure number="1">
                  <attributes>
                    <measure-style>
                      <multiple-rest>2</multiple-rest>
                    </measure-style>
                  </attributes>
                  <note><rest/><duration>4</duration></note>
                </measure>
              </part>
            </score-partwise>
            """
        let score = try parseMusicXMLScore(musicXML)
        let part = try #require(score.parts.first)
        var expansion = MusicXML.Importer.Walker.Expansion()

        let plan = expansion.plan(part.measures[0],
                                  at: 0,
                                  in: part)

        guard case let .items(items) = plan
        else {
            Issue.record("expected .items")
            return
        }

        #expect(items == part.measures[0].items)
    }

    @Test
    func plan_multipleRest_emptyCoveredMeasures_synthesizesRests() throws {
        let musicXML = """
            <?xml version="1.0" encoding="UTF-8"?>
            <score-partwise version="4.0">
              <part-list>
                <score-part id="P1"><part-name>P</part-name></score-part>
              </part-list>
              <part id="P1">
                <measure number="1">
                  <attributes>
                    <measure-style>
                      <multiple-rest>2</multiple-rest>
                    </measure-style>
                  </attributes>
                </measure>
                <measure number="2">
                </measure>
                <measure number="3">
                  <note><pitch><step>C</step><octave>4</octave></pitch><duration>4</duration></note>
                </measure>
              </part>
            </score-partwise>
            """
        let score = try parseMusicXMLScore(musicXML)
        let part = try #require(score.parts.first)
        var expansion = MusicXML.Importer.Walker.Expansion()

        let plans = part.measures.enumerated().map { index, measure in
            expansion.plan(measure, at: index, in: part)
        }

        guard case .syntheticRest = plans[0],
              case .syntheticRest = plans[1],
              case let .items(thirdItems) = plans[2]
        else {
            Issue.record("expected two synthetic rests followed by written items")
            return
        }

        #expect(thirdItems == part.measures[2].items)
    }

    @Test
    func plan_noMeasureStyle_returnsWrittenItemsUnchanged() throws {
        let musicXML = """
            <?xml version="1.0" encoding="UTF-8"?>
            <score-partwise version="4.0">
              <part-list>
                <score-part id="P1"><part-name>P</part-name></score-part>
              </part-list>
              <part id="P1">
                <measure number="1">
                  <note><pitch><step>C</step><octave>4</octave></pitch><duration>4</duration></note>
                </measure>
              </part>
            </score-partwise>
            """
        let score = try parseMusicXMLScore(musicXML)
        let part = try #require(score.parts.first)
        var expansion = MusicXML.Importer.Walker.Expansion()

        let plan = expansion.plan(part.measures[0],
                                  at: 0,
                                  in: part)

        guard case let .items(items) = plan
        else {
            Issue.record("expected .items")
            return
        }

        #expect(items == part.measures[0].items)
    }
}
