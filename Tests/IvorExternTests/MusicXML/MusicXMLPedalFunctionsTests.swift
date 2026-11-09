// © 2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import IvorModel
import IvorMXL
import IvorTiming
import Testing
import XestiNumbers
import XestiTools

struct MusicXMLPedalFunctionsTests {
}

// MARK: -

extension MusicXMLPedalFunctionsTests {
    @Test
    func makeMusicXMLPedalDirections_atOneTime_sustainThenSostenutoThenSoft() {
        let table = beatSustainTable([(0, .on)])
        let directions = makeMusicXMLPedalDirections([.soft: table, .sostenuto: table, .sustain: table])

        #expect(directions.map(\.0) == [0, 0, 0])
        #expect(directions.map { ExportedPedalDirection(pedals: pedalMarks($0.1), sound: $0.1.sound).marks } == [[.start], [.sostenuto], []])
        #expect(directions[2].1.sound?.softPedal == .yes)
    }

    @Test
    func makeMusicXMLPedalDirections_droppedPedals_writeNothing() {
        let table = beatSustainTable([(0, .on)])

        #expect(makeMusicXMLPedalDirections([.legato: table, .portamento: table]).isEmpty)
        #expect(makeMusicXMLPedalDirections([:]).isEmpty)
    }

    @Test
    func makeMusicXMLPedalDirections_partialLevels_writeSoundOnEntryAndExit() {
        let half = Pedal.Level(Number(numerator: 1, denominator: 2))
        let directions = makeMusicXMLPedalDirections([.sustain: beatSustainTable([(0, .on), (1, half), (2, .on), (3, .off)])])

        #expect(directions.map(\.0) == [0, 1, 2, 3])
        #expect(directions.map { $0.1.sound?.damperPedal } == [nil, .number(50), .yes, nil])
        #expect(directions.map { pedalMarks($0.1).map(\.kind) } == [[.start], [], [], [.stop]])
    }

    @Test
    func makeMusicXMLPedalDirections_unchangedLevel_writesNothing() {
        let directions = makeMusicXMLPedalDirections([.sustain: beatSustainTable([(0, .on), (1, .on)])])

        #expect(directions.count == 1)
    }
}
