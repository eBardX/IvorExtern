// © 2026 John Gary Pusey (see LICENSE.md)

internal import IvorTiming

// One piece of a part between two consecutive boundaries (bar lines, key
// changes, and every note's attack and release), with every tone sounding
// throughout it. A notation exporter writes each piece as one note, one
// chord, or one rest, tying each tone that continues past the piece into
// the next one. So a note held across a new attack is split and tied into
// the chord it overlaps, and no note of a part is lost or cut short.
internal struct ExportSlice {

    // MARK: Internal Instance Properties

    internal let end: BeatTime
    internal let start: BeatTime
    internal let tones: [ExportTone]
}

// MARK: -

extension ExportSlice {

    // MARK: Internal Type Methods

    // One slice per pair of consecutive `boundaries` (sorted, distinct, and
    // including every attack and release of `tones`), so `result[i]` runs
    // from `boundaries[i]` to `boundaries[i + 1]`. A slice's tones keep the
    // order of `tones`.
    internal static func slices(of tones: [ExportTone],
                                at boundaries: [BeatTime]) -> [Self] {
        var slices: [Self] = []
        var active: [ExportTone] = []
        var nextIndex = 0

        for (start, end) in zip(boundaries, boundaries.dropFirst()) {
            active.removeAll { $0.end <= start }

            while nextIndex < tones.count,
                  tones[nextIndex].attack <= start {
                if tones[nextIndex].end > start {
                    active.append(tones[nextIndex])
                }

                nextIndex += 1
            }

            slices.append(ExportSlice(end: end,
                                      start: start,
                                      tones: active.sorted { $0.index < $1.index }))
        }

        return slices
    }

    // MARK: Internal Instance Properties

    // The tones attacked at the start of this slice, rather than tied into
    // it from the one before.
    internal var attackedTones: [ExportTone] {
        tones.filter { $0.attack == start }
    }

    // Whether every tone continues into the next slice, so the whole note or
    // chord can be tied at once.
    internal var isWhollyTied: Bool {
        !tones.isEmpty && tones.allSatisfy(continues)
    }

    // The tones released at the end of this slice, rather than tied into the
    // next one.
    internal var releasedTones: [ExportTone] {
        tones.filter { !continues($0) }
    }

    // MARK: Internal Instance Methods

    // Whether `tone` continues past this slice, tied into the next one.
    internal func continues(_ tone: ExportTone) -> Bool {
        tone.end > end
    }

    // Whether `tone` was tied into this slice from the one before.
    internal func isTiedIn(_ tone: ExportTone) -> Bool {
        tone.attack < start
    }
}

// MARK: - Sendable

extension ExportSlice: Sendable {
}
