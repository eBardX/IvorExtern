// © 2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import IvorMIDI
import IvorModel
import IvorTiming
import IvorTuning
import Testing
import XestiNumbers
import XestiTools

struct PedalFunctionsTests {
}

// MARK: -

extension PedalFunctionsTests {
    @Test
    func controller_coversCC64Through68() {
        #expect(Pedal.allCases.map { controller(for: $0).uintValue }.sorted() == [64, 65, 66, 67, 68])
        #expect(controller(for: .sustain) == .sustain)
        #expect(controller(for: .soft) == .softPedal)
    }

    @Test
    func convertToMIDIValue_roundsToNearest() {
        #expect(convertToMIDIValue(.up).uintValue == 0)
        #expect(convertToMIDIValue(.down).uintValue == 127)
        #expect(convertToMIDIValue(Pedal.Level(Number(numerator: 1, denominator: 2))).uintValue == 64)
    }

    @Test
    func convertToPedal_isInverseOfController() {
        for pedal in Pedal.allCases {
            #expect(convertToPedal(controller(for: pedal)) == pedal)
        }

        #expect(convertToPedal(.channelVolumeMSB) == nil)
    }

    @Test
    func convertToPedalLevel_midiValue_isExact() {
        #expect(convertToPedalLevel(midiValue: MIDIData1Value(0)) == .up)
        #expect(convertToPedalLevel(midiValue: MIDIData1Value(127)) == .down)
        #expect(convertToPedalLevel(midiValue: MIDIData1Value(64)).numberValue == Number(numerator: 64, denominator: 127))

        for value in 0...127 {
            let data = MIDIData1Value(clamping: value)

            #expect(convertToMIDIValue(convertToPedalLevel(midiValue: data)) == data)
        }
    }

    @Test
    func convertToPedalLevel_percent() {
        #expect(convertToPedalLevel(percent: 0) == .up)
        #expect(convertToPedalLevel(percent: 100) == .down)
        #expect(convertToPedalLevel(percent: 50).numberValue == Number(numerator: 1, denominator: 2))
        #expect(convertToPedalLevel(percent: 150) == .down)
        #expect(convertToPedalLevel(percent: -5) == .up)
    }

    @Test
    func groupedByTime_keepsSameTimeEntriesInOrder() {
        let groups = groupedByTime(beatSustainTable([(0, .down), (1, .up), (1, .down), (2, .up)]))

        #expect(groups.map(\.time) == [0, 1, 2])
        #expect(groups.map(\.levels) == [[.down], [.up, .down], [.up]])
    }

    @Test
    func pedalSwitches_thresholdAtHalf() {
        let half = Pedal.Level(Number(numerator: 1, denominator: 2))

        #expect(pedalSwitches(after: .up, [.down]) == [true])
        #expect(pedalSwitches(after: .down, [.up]) == [false])
        #expect(pedalSwitches(after: .down, [.up, .down]) == [false, true])
        #expect(pedalSwitches(after: .down, [half]).isEmpty)
        #expect(pedalSwitches(after: .up, [.up]).isEmpty)
        #expect(pedalSwitches(after: .up, [.down, .up]).isEmpty)
        #expect(pedalSwitches(after: .up, []).isEmpty)
    }

    @Test
    func simplifyingPedals_simplifiesEveryPart() throws {
        let half = Pedal.Level(Number(numerator: 1, denominator: 2))
        var parts = makeKeyboardWallParts([[(0, 1, 60)], [(0, 1, 64)]])

        for index in parts.indices {
            parts[index].pedals[.sustain] = wallSustainTable([(0, .down), (1, half), (2, .up)])
        }

        let work = try simplifyingPedals(of: Work(content: .keyboardWall(parts)), .snap)
        let simplified = try #require(keyboardWallParts(of: work))

        #expect(simplified.map { $0.pedals[.sustain]?.map(\.level) } == [[.down, .up], [.down, .up]])
        #expect(simplified.map(\.partID) == parts.map(\.partID))
    }
}
