// © 2026 John Gary Pusey (see LICENSE.md)

internal import IvorMIDI
internal import IvorModel
internal import IvorTiming
internal import IvorTuning

private import Foundation
private import XestiNumbers
private import XestiTools

extension WorkPerformance {

    // MARK: Internal Nested Types

    // How a part's dynamics reach its held notes, which velocity alone can't.
    //
    // Velocity and CC 11 both follow 40·log₁₀(x/127) dB, so their gains
    // multiply. Velocity goes on carrying the level at each attack; CC 11
    // carries a gain relative to it, with 127 as unity. Inside a span (a run
    // of joined ramps) that gain is the level divided by the span's peak, and
    // an attack's velocity is divided by the gain then, so that it lands at
    // the written level.
    //
    // A held note would jump if the gain moved under it, so a span's gain
    // takes hold where the sounding run around its start begins, and lets go
    // where the next run after its end begins. Spans whose runs overlap
    // become one, and a step inside one fades in just before it lands. A
    // span where no note would drift by `minimumDrift` isn't worth it, and
    // leaves velocity to do the work alone.
    //
    // A part whose map holds exact expression (an importer's
    // `expressionValue`) plays that instead, and its velocities stay as
    // they are.
    internal struct Expression {

        // MARK: Internal Initializers

        internal init(part: Part<WallTime, NoteNumber>) {
            let levels = part.dynamicMap.map { (time: $0.time.uintValue, level: $0.dynamic.doubleValue) }

            self.attacks = part.noteTable.map(\.attack.uintValue)
            self.dynamicMap = part.dynamicMap
            self.exactValues = part.dynamicMap.compactMap { entry in
                intValue(entry.extras, .expressionValue).map { (entry.time, UInt(clamping: $0)) }
            }
            self.runs = Self._runs(of: part)
            self.steps = zip(levels, levels.dropFirst()).compactMap { $0.time == $1.time && $0.level != $1.level ? $0.time : nil }
            self.spans = exactValues.isEmpty ? Self._spans(of: part, levels: levels, runs: runs) : []
        }

        // MARK: Private Nested Types

        private struct Run {

            // MARK: Fileprivate Instance Properties

            fileprivate var end: UInt
            fileprivate let start: UInt
        }

        private struct Span {

            // MARK: Fileprivate Instance Properties

            fileprivate let begin: UInt     // where the gain takes hold
            fileprivate var end: UInt?      // where it lets go, or `nil` if it never needs to
            fileprivate var last: UInt      // when the ramps end
            fileprivate var peak: Double
            fileprivate let start: UInt     // when the ramps start
        }

        // MARK: Private Instance Properties

        private let attacks: [UInt]
        private let dynamicMap: DynamicMap<WallTime>
        private let exactValues: [(time: WallTime, value: UInt)]
        private let runs: [Run]
        private let spans: [Span]
        private let steps: [UInt]
    }
}

// MARK: -

extension WorkPerformance.Expression {

    // MARK: Internal Instance Methods

    // The messages that play this expression on `channels`.
    internal func events(on channels: [MIDIChannel]) -> [WorkPerformance.Event] {
        var events: [WorkPerformance.Event] = []

        for channel in channels {
            if exactValues.isEmpty {
                for (time, value) in _controllerValues() {
                    events.append(.init(time: time,
                                        message: .controlChange(channel, .expressionControllerMSB, value)))
                }
            } else {
                events += _exactEvents(on: channel)
            }
        }

        return events
    }

    // The times from `start` through `end`, on the controller grid, where a
    // note is sounding.
    internal func gridTimes(from start: WallTime,
                            through end: WallTime) -> [WallTime] {
        stride(from: start.uintValue,
               to: end.uintValue,
               by: Self.gridInterval).compactMap { _isSounding($0) ? WallTime($0) : nil }
    }

    // The velocity for an attack at `time` that sounds as `velocity` would
    // with the channel at unity.
    internal func velocity(_ velocity: MIDIData1Value,
                           at time: WallTime) -> MIDIData1Value {
        guard !spans.isEmpty
        else { return velocity }

        let value = Double(_controllerValue(at: time.uintValue).uintValue)
        let compensated = (Double(velocity.uintValue) * 127.0 / value).rounded()

        return MIDIData1Value(clamping: UInt(max(1, min(compensated, 127))))
    }

    // MARK: Private Type Properties

    private static let gridInterval = 20_000      // 20 ms, which listening showed fine even for a fast hairpin
    private static let minimumDrift = 1.0               // dB; about the least change that can be heard
    private static let minimumLevel = 1.0 / 127.0
    private static let stepFade = 30_000                // 30 ms, since the synth doesn't smooth CC 11

    // MARK: Private Type Methods

    private static func _drifts(_ part: Part<WallTime, NoteNumber>,
                                from start: WallTime,
                                through end: WallTime) -> Bool {
        part.noteTable.contains { note in
            let from = max(note.attack, start)
            let through = min(note.release, end)

            guard from < through
            else { return false }

            let ends = [part.dynamicMap[from].doubleValue, part.dynamicMap[through].doubleValue].map { max($0, minimumLevel) }

            return 40.0 * log10((ends.max() ?? 1) / (ends.min() ?? 1)) >= minimumDrift
        }
    }

    // The note table's stretches of unbroken sound. Notes that touch are one
    // run, since there is no silence to move the gain in.
    private static func _runs(of part: Part<WallTime, NoteNumber>) -> [Run] {
        var runs: [Run] = []

        for note in part.noteTable.sorted(by: { $0.attack < $1.attack }) {
            let (attack, release) = (note.attack.uintValue, note.release.uintValue)

            if let last = runs.last, attack <= last.end {
                runs[runs.count - 1].end = max(last.end, release)
            } else {
                runs.append(Run(end: release, start: attack))
            }
        }

        return runs
    }

    private static func _spans(of part: Part<WallTime, NoteNumber>,
                               levels: [(time: UInt, level: Double)],
                               runs: [Run]) -> [Span] {
        var spans: [Span] = []
        var index = 0

        while index + 1 < levels.count {
            guard _isRamp(levels, index)
            else { index += 1; continue }

            var last = index + 1
            var drifts = _drifts(part, levels, index)

            while last + 1 < levels.count, _isRamp(levels, last) {
                drifts = drifts || _drifts(part, levels, last)
                last += 1
            }

            if drifts {
                let span = _span(levels[index...last], runs: runs)

                if let previous = spans.last, span.begin < previous.end ?? .max {
                    spans[spans.count - 1].end = span.end
                    spans[spans.count - 1].last = span.last
                    spans[spans.count - 1].peak = max(previous.peak, span.peak)
                } else {
                    spans.append(span)
                }
            }

            index = last
        }

        return spans
    }

    private static func _drifts(_ part: Part<WallTime, NoteNumber>,
                                _ levels: [(time: UInt, level: Double)],
                                _ index: Int) -> Bool {
        _drifts(part,
                from: WallTime(levels[index].time),
                through: WallTime(levels[index + 1].time))
    }

    private static func _isRamp(_ levels: [(time: UInt, level: Double)],
                                _ index: Int) -> Bool {
        levels[index].time < levels[index + 1].time && levels[index].level != levels[index + 1].level
    }

    private static func _span(_ levels: ArraySlice<(time: UInt, level: Double)>,
                              runs: [Run]) -> Span {
        let start = levels.first?.time ?? 0
        let last = levels.last?.time ?? 0
        let startRun = runs.first { $0.start < start && start < $0.end }
        let lastRun = runs.first { $0.start < last && last < $0.end }
        let end = runs.first { $0.start >= (lastRun?.end ?? last) }?.start

        return Span(begin: startRun?.start ?? start,
                    end: end,
                    last: last,
                    peak: levels.map(\.level).max() ?? 1,
                    start: start)
    }

    // MARK: Private Instance Methods

    private func _controllerValue(at time: UInt) -> MIDIData1Value {
        let gain = spans.first { $0.begin <= time && time < ($0.end ?? .max) }.map { span in
            _level(at: min(max(time, span.start), span.last)) / span.peak
        }

        return MIDIData1Value(clamping: UInt(max(1, min(((gain ?? 1) * 127).rounded(), 127))))
    }

    private func _controllerValues() -> [(WallTime, MIDIData1Value)] {
        var times = Set(attacks + [0])

        for span in spans {
            times.formUnion(gridTimes(from: WallTime(span.start),
                                      through: WallTime(span.last)).map(\.uintValue))

            if _isSounding(span.last) {
                times.insert(span.last)
            }

            for step in steps where span.start + UInt(Self.stepFade) <= step && step <= span.last {
                let ticks = stride(from: step - UInt(Self.stepFade), through: step, by: Self.stepFade / 3)

                times.formUnion(ticks.filter(_isSounding))
            }
        }

        var values: [(WallTime, MIDIData1Value)] = []

        for time in times.sorted() {
            let value = _controllerValue(at: time)

            if values.last?.1 != value {
                values.append((WallTime(time), value))
            }
        }

        return values
    }

    private func _exactEvents(on channel: MIDIChannel) -> [WorkPerformance.Event] {
        var events: [WorkPerformance.Event] = []

        if exactValues.first?.time != .zero {
            events.append(.init(time: .zero,
                                message: .controlChange(channel, .expressionControllerMSB, MIDIData1Value(clamping: 127))))
        }

        for (time, value) in exactValues {
            events.append(.init(time: time,
                                message: .controlChange(channel, .expressionControllerMSB, MIDIData1Value(clamping: value >> 7))))
            events.append(.init(time: time,
                                message: .controlChange(channel, .expressionControllerLSB, MIDIData1Value(clamping: value & 0x7f))))
        }

        return events
    }

    private func _isSounding(_ time: UInt) -> Bool {
        runs.contains { $0.start <= time && time < $0.end }
    }

    // The level at `time`, fading into any step just ahead of it.
    private func _level(at time: UInt) -> Double {
        let level = max(dynamicMap[WallTime(time)].doubleValue, Self.minimumLevel)

        let fade = UInt(Self.stepFade)

        guard let step = steps.first(where: { $0 >= fade && $0 - fade <= time && time < $0 })
        else { return level }

        let before = max(dynamicMap[WallTime(step - fade)].doubleValue, Self.minimumLevel)
        let after = max(dynamicMap[WallTime(step)].doubleValue, Self.minimumLevel)
        let fraction = Double(time - (step - fade)) / Double(fade)

        return before + (after - before) * fraction
    }
}
