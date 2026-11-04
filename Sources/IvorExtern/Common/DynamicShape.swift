// © 2026 John Gary Pusey (see LICENSE.md)

internal import IvorModel
internal import IvorTiming

private import XestiTools

// What a dynamic map's entries say, for an exporter whose format writes
// marks and hairpins rather than entries, per the module-wide positional
// convention: entries at the *same* time are an instantaneous step, and
// two entries at *different* times and levels are a ramp.
internal enum DynamicShape {
    case mark(time: BeatTime, dynamic: Dynamic, mark: String?)
    case ramp(start: BeatTime, startDynamic: Dynamic, end: BeatTime, endDynamic: Dynamic)
}

// MARK: -

extension DynamicShape {

    // MARK: Internal Type Methods

    // A step is one mark, at the level of the last of its entries (which
    // may be more than two, for a chord's velocities). Two entries at the
    // same level are no ramp, so the first stands alone and the second is
    // looked at again, since it may be the reasserted first half of a step.
    // An entry that stands alone is a mark, unless it only repeats the level
    // already in effect.
    internal static func shapes(of dynamicMap: DynamicMap<BeatTime>) -> [Self] {
        var entries: [(time: BeatTime, dynamic: Dynamic, mark: String?)] = []

        for entry in dynamicMap {
            entries.append((entry.time, entry.dynamic, stringValue(entry.extras, .dynamicMark)))
        }

        var shapes: [Self] = []
        var index = 0
        var level: Dynamic?

        while index < entries.count {
            let (time, dynamic, mark) = entries[index]

            let next = index + 1 < entries.count ? entries[index + 1] : nil

            if let next, next.time == time {
                var last = index + 1

                while last + 1 < entries.count, entries[last + 1].time == time {
                    last += 1
                }

                shapes.append(.mark(time: time, dynamic: entries[last].dynamic, mark: entries[last].mark))

                level = entries[last].dynamic
                index = last + 1
            } else if let next, next.dynamic != dynamic {
                shapes.append(.ramp(start: time, startDynamic: dynamic, end: next.time, endDynamic: next.dynamic))

                level = next.dynamic
                index += 2
            } else {
                if mark != nil || dynamic != level {
                    shapes.append(.mark(time: time, dynamic: dynamic, mark: mark))
                }

                level = dynamic
                index += 1
            }
        }

        return shapes
    }
}
