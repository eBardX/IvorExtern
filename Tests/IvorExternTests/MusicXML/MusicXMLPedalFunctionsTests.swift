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
        let table = beatSustainTable([(0, .down)])
        let directions = makeMusicXMLPedalDirections([.soft: table, .sostenuto: table, .sustain: table])

        #expect(directions.map(\.0) == [0, 0, 0])
        #expect(directions.map { ExportedPedalDirection(pedals: pedalMarks($0.1), sound: $0.1.sound).marks } == [[.start], [.sostenuto], []])
        #expect(directions[2].1.sound?.softPedal == .yes)
    }

    @Test
    func makeMusicXMLPedalDirections_droppedPedals_writeNothing() {
        let table = beatSustainTable([(0, .down)])

        #expect(makeMusicXMLPedalDirections([.legato: table, .portamento: table]).isEmpty)
        #expect(makeMusicXMLPedalDirections([:]).isEmpty)
    }

    @Test
    func makeMusicXMLPedalDirections_hidden_writesSoundAlone() {
        let half = Pedal.Level(Number(numerator: 1, denominator: 2))
        let table = beatSustainTable([(0, .down), (1, .up), (1, .down), (2, half), (3, .up)])
        let directions = makeMusicXMLPedalDirections([.sustain: table],
                                                     hidden: [.sustain])

        #expect(directions.map(\.0) == [0, 1, 1, 2, 3])
        #expect(directions.map { $0.1.sound?.damperPedal } == [.yes, .no, .yes, .number(50), .no])
        #expect(directions.allSatisfy { pedalMarks($0.1).isEmpty })
    }

    @Test
    func makeMusicXMLPedalDirections_partialLevels_writeSoundOnEntryAndExit() {
        let half = Pedal.Level(Number(numerator: 1, denominator: 2))
        let directions = makeMusicXMLPedalDirections([.sustain: beatSustainTable([(0, .down), (1, half), (2, .down), (3, .up)])])

        #expect(directions.map(\.0) == [0, 1, 2, 3])
        #expect(directions.map { $0.1.sound?.damperPedal } == [nil, .number(50), .yes, nil])
        #expect(directions.map { pedalMarks($0.1).map(\.kind) } == [[.start], [], [], [.stop]])
    }

    @Test
    func makeMusicXMLPedalDirections_softRepedal_writesUpThenDown() {
        let directions = makeMusicXMLPedalDirections([.soft: beatSustainTable([(0, .down), (1, .up), (1, .down)])])

        #expect(directions.map(\.0) == [0, 1, 1])
        #expect(directions.map { $0.1.sound?.softPedal } == [.yes, .no, .yes])
    }

    @Test
    func makeMusicXMLPedalDirections_unchangedLevel_writesNothing() {
        let directions = makeMusicXMLPedalDirections([.sustain: beatSustainTable([(0, .down), (1, .down)])])

        #expect(directions.count == 1)
    }

    @Test
    func repeatedPedals_hidesTablesAnEarlierPartShows() {
        let sustain = beatSustainTable([(0, .down), (2, .up)])
        let other = beatSustainTable([(0, .down), (3, .up)])
        let hidden = repeatedPedals([[.sustain: sustain],
                                     [.sostenuto: sustain, .sustain: sustain],
                                     [.soft: sustain, .sustain: other],
                                     [.sostenuto: sustain, .sustain: other]])

        #expect(hidden == [[], [.sustain], [], [.sostenuto, .sustain]])
    }
}
