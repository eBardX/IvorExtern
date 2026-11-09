// © 2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import IvorMIDI
import IvorModel
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
        #expect(convertToMIDIValue(.off).uintValue == 0)
        #expect(convertToMIDIValue(.on).uintValue == 127)
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
        #expect(convertToPedalLevel(midiValue: MIDIData1Value(0)) == .off)
        #expect(convertToPedalLevel(midiValue: MIDIData1Value(127)) == .on)
        #expect(convertToPedalLevel(midiValue: MIDIData1Value(64)).numberValue == Number(numerator: 64, denominator: 127))

        for value in 0...127 {
            let data = MIDIData1Value(clamping: value)

            #expect(convertToMIDIValue(convertToPedalLevel(midiValue: data)) == data)
        }
    }

    @Test
    func convertToPedalLevel_percent() {
        #expect(convertToPedalLevel(percent: 0) == .off)
        #expect(convertToPedalLevel(percent: 100) == .on)
        #expect(convertToPedalLevel(percent: 50).numberValue == Number(numerator: 1, denominator: 2))
        #expect(convertToPedalLevel(percent: 150) == .on)
        #expect(convertToPedalLevel(percent: -5) == .off)
    }

    @Test
    func groupedByTime_keepsSameTimeEntriesInOrder() {
        let groups = groupedByTime(beatSustainTable([(0, .on), (1, .off), (1, .on), (2, .off)]))

        #expect(groups.map(\.time) == [0, 1, 2])
        #expect(groups.map(\.levels) == [[.on], [.off, .on], [.off]])
    }

    @Test
    func pedalSwitches_thresholdAtHalf() {
        let half = Pedal.Level(Number(numerator: 1, denominator: 2))

        #expect(pedalSwitches(after: .off, [.on]) == [true])
        #expect(pedalSwitches(after: .on, [.off]) == [false])
        #expect(pedalSwitches(after: .on, [.off, .on]) == [false, true])
        #expect(pedalSwitches(after: .on, [half]).isEmpty)
        #expect(pedalSwitches(after: .off, [.off]).isEmpty)
        #expect(pedalSwitches(after: .off, [.on, .off]).isEmpty)
        #expect(pedalSwitches(after: .off, []).isEmpty)
    }
}
