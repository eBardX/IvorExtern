// © 2025–2026 John Gary Pusey (see LICENSE.md)

internal import IvorTiming
internal import XestiNumbers

private import IvorMIDI
private import IvorModel
private import XestiTools

extension MIDI {

    // MARK: Internal Nested Types

    internal struct BeatMap {

        // MARK: Internal Initializers

        internal init(division: MIDI.Division) throws(MIDI.Error) {
            switch division {
            case let .metrical(tickRate):
                self.tickRate = tickRate.uintValue

            default:
                throw MIDI.Error.unsupportedDivision(division)
            }

            self.entries = [Entry(eventTime: .zero,
                                  beatTime: .zero,
                                  factor: 1)]
        }

        // MARK: Private Instance Properties

        private let tickRate: UInt

        private var entries: [Entry]
    }
}

// MARK: -

extension MIDI.BeatMap {

    // MARK: Internal Type Aliases

    internal typealias Factor = Number

    // MARK: Internal Instance Subscripts

    internal subscript(eventTime: MIDI.EventTime) -> (BeatTime, Factor) {
        guard !entries.isEmpty
        else { return (.zero, 1) }

        let maxIndex = entries.endIndex - 1

        guard let idx = entries.firstIndex(where: { eventTime < $0.eventTime })
        else { return (_beatTime(for: eventTime,
                                 after: entries[maxIndex]),
                       entries[maxIndex].factor) }

        guard idx > 0
        else { return (entries[0].beatTime,
                       entries[0].factor) }

        let entry = entries[idx - 1]

        return (_beatTime(for: eventTime,
                          after: entry),
                entry.factor)
    }

    // MARK: Internal Instance Methods

    internal mutating func append(eventTime: MIDI.EventTime,
                                  clockRate: UInt) throws(MIDI.Error) {
        guard eventTime >= 0
        else { throw MIDI.Error.invalidEventTime(eventTime) }

        guard clockRate > 0
        else { throw MIDI.Error.invalidClockRate(clockRate) }

        guard let lastEntry = entries.last
        else { throw MIDI.Error.emptyBeatMap }

        guard eventTime >= lastEntry.eventTime
        else { throw MIDI.Error.invalidEventTime(eventTime) }

        entries.insert(Entry(eventTime: eventTime,
                             beatTime: _beatTime(for: eventTime,
                                                 after: lastEntry),
                             factor: Number(numerator: 24,
                                            denominator: Number(clockRate))),
                       at: entries.count)
    }

    // MARK: Private Instance Methods

    private func _beatTime(for eventTime: MIDI.EventTime,
                           after entry: MIDI.BeatMap.Entry) -> BeatTime {
        BeatTime(entry.beatTime.numberValue +
                 (entry.factor *
                  Number(numerator: eventTime.uintValue - entry.eventTime.uintValue,
                         denominator: tickRate)))
    }
}
