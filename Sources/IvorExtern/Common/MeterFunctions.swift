// © 2026 John Gary Pusey (see LICENSE.md)

internal import IvorModel
internal import IvorTiming
internal import XestiNumbers
internal import XestiTools

// MARK: Internal Functions

// The bars an exporter writes for a work with this meter table, in order,
// from time 0 until they cover `end` (the end of the music): every bar of the
// table's grid, short bars at their actual length, and the last bar at its
// full length. Before the first entry, bars of its meter are counted back
// from it, so a part-bar at the start is a pickup (a free first meter gives
// one free bar instead). A meterless work (an empty table) is written in 4/4.
// The meter is written at the first bar and wherever the meter or its
// `meterSymbol` changes, so a restart (or a redundant entry) is written only
// as a barline.
internal func exportBars(_ meterTable: MeterTable,
                         through end: BeatTime) -> [ExportBar] {
    let table = meterTable.isEmpty ? commonTimeTable : meterTable

    guard let first = table.first,
          let last = table.last
    else { return [] }

    var bars: [ExportBar] = []

    if first.beatTime > .zero {
        bars += _leadingBars(before: first)
    }

    let upper = end > last.beatTime ? end : last.beatTime + (last.meter.barLength ?? .quarter)

    for bar in table.bars(overlapping: first.beatTime..<upper) {
        bars.append(ExportBar(extras: table.last { $0.beatTime <= bar.range.lowerBound }?.extras,
                              isMeterWritten: false,
                              isPickup: bar.isPickup,
                              length: bar.range.upperBound - bar.range.lowerBound,
                              meter: bar.meter,
                              start: bar.range.lowerBound))
    }

    var written: (meter: Meter, symbol: String?)?

    return bars.map { bar in
        let symbol = stringValue(bar.extras, .meterSymbol)
        let isMeterWritten = written.map { $0.meter != bar.meter || $0.symbol != symbol } ?? true

        if isMeterWritten {
            written = (bar.meter, symbol)
        }

        return ExportBar(extras: bar.extras,
                         isMeterWritten: isMeterWritten,
                         isPickup: bar.isPickup,
                         length: bar.length,
                         meter: bar.meter,
                         start: bar.start)
    }
}

// Builds an imported work's meter table from the barlines its source
// declares, in time order: each barline is where a bar in `meter` starts
// (with the `extras` the source writes there, if any). An entry is added
// wherever the meter changes, wherever a barline falls off the grid the
// table already implies (a short bar before it becomes a restart), and
// wherever new extras are written; any other barline is already on the grid.
// A restart keeps the extras of the entry it restarts. Two barlines at the
// same time: the later one wins. Finally, a short first bar at time 0 becomes
// the table's pickup.
internal func makeMeterTable(_ barlines: [(beatTime: BeatTime, meter: Meter, extras: Extras?)]) -> MeterTable {
    var table = MeterTable()

    for barline in barlines {
        _add(barline, to: &table)
    }

    _makePickup(&table)

    return table
}

// MARK: Private Constants

private let commonTimeTable: MeterTable = {
    var table = MeterTable()

    if let meter = Meter(numerators: [4],
                         denominator: 4) {
        _ = try? table.insert(beatTime: .zero,
                              meter: meter)
    }

    return table
}()

// MARK: Private Functions

private func _add(_ barline: (beatTime: BeatTime, meter: Meter, extras: Extras?),
                  to table: inout MeterTable) {
    let current = table.last { $0.beatTime <= barline.beatTime }

    if let current {
        let isSameMeter = current.meter == barline.meter

        if current.beatTime == barline.beatTime {
            _ = try? table.update(entryID: current.entryID,
                                  meter: barline.meter,
                                  extras: barline.extras ?? (isSameMeter ? current.extras : nil))

            return
        }

        if isSameMeter,
           barline.extras == nil || barline.extras == current.extras,
           _isBarline(barline.beatTime, in: table) {
            return
        }

        _ = try? table.insert(beatTime: barline.beatTime,
                              meter: barline.meter,
                              extras: barline.extras ?? (isSameMeter ? current.extras : nil))
    } else {
        _ = try? table.insert(beatTime: barline.beatTime,
                              meter: barline.meter,
                              extras: barline.extras)
    }
}

private func _isBarline(_ beatTime: BeatTime,
                        in table: MeterTable) -> Bool {
    guard let position = table.position(at: beatTime)
    else { return false }

    return position.offset.isZero && (position.beat ?? 1) == 1
}

// Counting back from the first entry, the bars of its meter before it,
// starting with a pickup if they don't fit exactly; a free meter gives one
// free bar instead. Whether each bar's meter is written is worked out later.
private func _leadingBars(before first: MeterTable.Entry) -> [ExportBar] {
    let span = first.beatTime - BeatTime.zero

    func bar(_ start: BeatTime,
             _ length: BeatDuration,
             isPickup: Bool) -> ExportBar {
        ExportBar(extras: first.extras,
                  isMeterWritten: false,
                  isPickup: isPickup,
                  length: length,
                  meter: first.meter,
                  start: start)
    }

    guard let barLength = first.meter.barLength
    else { return [bar(.zero, span, isPickup: false)] }

    let count = floor(span.numberValue / barLength.numberValue)
    let pickup = BeatDuration(span.numberValue - count * barLength.numberValue)
    var bars: [ExportBar] = []
    var start = BeatTime.zero

    if !pickup.isZero {
        bars.append(bar(start, pickup, isPickup: true))
        start += pickup
    }

    while start < first.beatTime {
        bars.append(bar(start, barLength, isPickup: false))
        start += barLength
    }

    return bars
}

// A short first bar at time 0 — one cut off by the second entry before it
// reaches its bar length — becomes the pickup. If the second entry only
// restarts the first meter, it's on the new grid and goes.
private func _makePickup(_ table: inout MeterTable) {
    guard table.count > 1
    else { return }

    let first = table[table.startIndex]
    let second = table[table.index(after: table.startIndex)]

    guard first.beatTime == .zero,
          let barLength = first.meter.barLength
    else { return }

    let pickup = second.beatTime - first.beatTime

    guard pickup < barLength
    else { return }

    if second.meter == first.meter,
       second.extras == first.extras {
        table.remove(entryID: second.entryID)
    }

    try? table.setPickup(pickup)
}
