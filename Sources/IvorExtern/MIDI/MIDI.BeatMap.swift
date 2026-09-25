// © 2025–2026 John Gary Pusey (see LICENSE.md)

internal import IvorTiming
internal import XestiNumbers

private import IvorModel
private import IvorSMF
private import IvorSMPTE
private import XestiTools

extension MIDI {

    // MARK: Internal Nested Types

    internal struct BeatMap {

        // MARK: Internal Initializers

        // With a metrical division, a tick is a fixed fraction of a quarter
        // note. With a timecode division, a tick is a fixed fraction of a
        // second — one exact division by the frame rate and ticks per frame —
        // so the quarter notes a tick spans depend on the tempo in effect,
        // and every tempo change starts a new entry.
        internal init(division: MIDI.Division) throws(MIDI.Error) {
            switch division {
            case let .metrical(tickRate):
                guard tickRate.uintValue > 0
                else { throw MIDI.Error.unsupportedDivision(division) }

                self.tickRate = tickRate.uintValue
                self.ticksPerSecond = nil

            case let .timeCode(timeCode):
                self.tickRate = nil
                self.ticksPerSecond = timeCode.frameRate.numberValue * Number(timeCode.ticksPerFrame)
            }

            self.entries = [Entry(eventTime: .zero,
                                  beatTime: .zero,
                                  factor: 1,
                                  tempo: MIDI.BeatMap.defaultTempo)]
        }

        // MARK: Private Instance Properties

        private let tickRate: UInt?
        private let ticksPerSecond: Number?

        private var entries: [Entry]
    }
}

// MARK: -

extension MIDI.BeatMap {

    // MARK: Internal Type Aliases

    internal typealias Factor = Number

    // MARK: Internal Type Properties

    // The tempo in effect until the first tempo event, in microseconds per
    // quarter note (120 BPM), per the Standard MIDI File specification.
    internal static let defaultTempo: UInt = 500_000

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
                                            denominator: Number(clockRate)),
                             tempo: lastEntry.tempo),
                       at: entries.count)
    }

    // Tempo changes only move beat times when ticks measure wall time, so
    // with a metrical division they leave the map untouched.
    internal mutating func append(eventTime: MIDI.EventTime,
                                  tempo: UInt) throws(MIDI.Error) {
        guard ticksPerSecond != nil
        else { return }

        guard tempo > 0
        else { throw MIDI.Error.invalidTempo(tempo) }

        guard let lastEntry = entries.last
        else { throw MIDI.Error.emptyBeatMap }

        guard eventTime >= lastEntry.eventTime
        else { throw MIDI.Error.invalidEventTime(eventTime) }

        entries.insert(Entry(eventTime: eventTime,
                             beatTime: _beatTime(for: eventTime,
                                                 after: lastEntry),
                             factor: lastEntry.factor,
                             tempo: tempo),
                       at: entries.count)
    }

    // MARK: Private Instance Methods

    private func _beatTime(for eventTime: MIDI.EventTime,
                           after entry: MIDI.BeatMap.Entry) -> BeatTime {
        BeatTime(entry.beatTime.numberValue +
                 (entry.factor *
                  _quarterNotes(eventTime.uintValue - entry.eventTime.uintValue,
                                entry.tempo)))
    }

    private func _quarterNotes(_ ticks: UInt,
                               _ tempo: UInt) -> Number {
        if let ticksPerSecond {
            return Number(ticks) * 1_000_000 / (ticksPerSecond * Number(tempo))
        }

        return Number(numerator: ticks,
                      denominator: tickRate ?? 1)
    }
}
