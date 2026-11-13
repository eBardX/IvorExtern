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

        // Beat times count whole notes. With a metrical division, a tick is
        // a fixed fraction of a quarter note, so a whole note is four times
        // the division's ticks per quarter. With a timecode division, a tick
        // is a fixed fraction of a second — one exact division by the frame
        // rate and ticks per frame — so the whole notes a tick spans depend
        // on the tempo in effect, and every tempo change starts a new entry.
        // Time signatures never affect timing: clocks per click only says
        // where the metronome clicks.
        internal init(division: MIDI.Division) {
            switch division {
            case let .metrical(tickRate):
                self.tickRate = tickRate.uintValue
                self.ticksPerSecond = nil

            case let .timeCode(timeCode):
                self.tickRate = nil
                self.ticksPerSecond = timeCode.frameRate.numberValue * Number(timeCode.ticksPerFrame)
            }

            self.entries = [Entry(eventTime: .zero,
                                  beatTime: .zero,
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

    // MARK: Internal Type Properties

    // The tempo in effect until the first tempo event, in microseconds per
    // quarter note (120 BPM), per the Standard MIDI File specification.
    internal static let defaultTempo: UInt = 500_000

    // MARK: Internal Instance Subscripts

    internal subscript(eventTime: MIDI.EventTime) -> BeatTime {
        guard !entries.isEmpty
        else { return .zero }

        let maxIndex = entries.endIndex - 1

        guard let idx = entries.firstIndex(where: { eventTime < $0.eventTime })
        else { return _beatTime(for: eventTime,
                                after: entries[maxIndex]) }

        guard idx > 0
        else { return entries[0].beatTime }

        return _beatTime(for: eventTime,
                         after: entries[idx - 1])
    }

    // MARK: Internal Instance Methods

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
                             tempo: tempo),
                       at: entries.count)
    }

    // MARK: Private Instance Methods

    private func _beatTime(for eventTime: MIDI.EventTime,
                           after entry: MIDI.BeatMap.Entry) -> BeatTime {
        BeatTime(entry.beatTime.numberValue +
                 _wholeNotes(eventTime.uintValue - entry.eventTime.uintValue,
                             entry.tempo))
    }

    private func _wholeNotes(_ ticks: UInt,
                             _ tempo: UInt) -> Number {
        if let ticksPerSecond {
            return Number(ticks) * 250_000 / (ticksPerSecond * Number(tempo))
        }

        return Number(numerator: ticks,
                      denominator: 4 * (tickRate ?? 1))
    }
}

// MARK: - MIDI.ImportTimeMap

extension MIDI.BeatMap: MIDI.ImportTimeMap {

    // MARK: Internal Instance Methods

    internal func time(at eventTime: MIDI.EventTime) -> BeatTime {
        self[eventTime]
    }

    internal func timeSpan(at eventTime: MIDI.EventTime,
                           ticks: UInt) -> (BeatTime, BeatDuration) {
        let attack = time(at: eventTime)
        let release = time(at: MIDI.EventTime(eventTime.uintValue + ticks))

        return (attack, release - attack)
    }
}
