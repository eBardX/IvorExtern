// © 2026 John Gary Pusey (see LICENSE.md)

internal import IvorABC

// Builds a replay order — a list of index ranges into one voice's own
// `[ABC.Importer.Item]` stream — from its `P:` sequence, repeat markers, and
// variant endings, ported from upstream's own repeat/variant-ending
// expansion and parts-sequence flattening. `ABC.Importer.Walker` streams the
// resulting ranges once, resolving duration/pitch/macros as it goes; the
// plan itself holds no music, only *where to visit* — O(measures), not a
// parallel model.
//
// Differs from upstream in one deliberate way: upstream's ranges are
// computed *after* full symbol resolution, over an already-flattened event
// stream from which bar lines have been dropped entirely (nothing
// downstream needs them once pitches/durations are final). Here the plan
// runs directly over the unresolved AST stream, and a bar line still carries
// meaning the walker needs — it resets bar-level accidental propagation
// (§4.6) — so, unlike upstream, an ordinary (non-repeat) bar line that is
// actually being played is kept in the output ranges as a singleton index,
// not dropped. A skipped bar line (inside a non-matching variant ending)
// remains excluded, exactly as upstream excludes it.
extension ABC.Importer {

    // MARK: Internal Nested Types

    internal struct Plan {

        // MARK: Internal Initializers

        internal init(items: [ABC.Importer.Item]) {
            self.items = items
        }

        // MARK: Private Instance Properties

        private let items: [ABC.Importer.Item]
    }
}

// MARK: -

extension ABC.Importer.Plan {

    // MARK: Internal Instance Methods

    // If the tune header declared a `P:` sequence, splits `items` into
    // segments keyed by `.part` marker, expands repeats within each segment
    // independently, then reassembles per the sequence's flat `expansion`
    // string. Otherwise expands repeats once over the whole stream as a
    // single unlabeled segment.
    internal func ranges() throws(ABC.Error) -> [Range<Int>] {
        guard let sequence = Self._partSequence(in: items)
        else { return try _expandedRepeatRanges(items.startIndex..<items.endIndex) }

        var segment0Range = items.startIndex..<items.startIndex
        var bodySegmentRanges: [ABCPart: Range<Int>] = [:]
        var currentPart: ABCPart?
        var currentStart = items.startIndex

        for (index, item) in items.enumerated() {
            guard case let .field(.part(part)) = item
            else { continue }

            if let currentPart {
                bodySegmentRanges[currentPart] = currentStart..<index
            } else {
                segment0Range = currentStart..<index
            }

            currentPart = part
            currentStart = index + 1
        }

        if let currentPart {
            bodySegmentRanges[currentPart] = currentStart..<items.endIndex
        } else {
            segment0Range = currentStart..<items.endIndex
        }

        // A voice whose body never declares any `.part` marker of its own
        // doesn't participate in the tune's part structure (e.g. a voice the
        // body switches straight past without ever using it) — the tune
        // header's `P:` field is still duplicated into every voice's stream,
        // so without this check every such voice would spuriously fail to
        // resolve every letter in the sequence.
        guard !bodySegmentRanges.isEmpty
        else { return try _expandedRepeatRanges(items.startIndex..<items.endIndex) }

        var result = try _expandedRepeatRanges(segment0Range)

        for letter in sequence.expansion {
            guard let part = Self._part(for: letter)
            else { continue }

            guard let segmentRange = bodySegmentRanges[part]
            else { throw ABC.Error.undefinedPart("P: sequence references part ‘\(letter)’, undefined in the tune body") }

            try result.append(contentsOf: _expandedRepeatRanges(segmentRange))
        }

        return result
    }

    // MARK: Private Type Properties

    private static let partsByLetter: [Character: ABCPart] = ["A": .a,
                                                              "B": .b,
                                                              "C": .c,
                                                              "D": .d,
                                                              "E": .e,
                                                              "F": .f,
                                                              "G": .g,
                                                              "H": .h,
                                                              "I": .i,
                                                              "J": .j,
                                                              "K": .k,
                                                              "L": .l,
                                                              "M": .m,
                                                              "N": .n,
                                                              "O": .o,
                                                              "P": .p,
                                                              "Q": .q,
                                                              "R": .r,
                                                              "S": .s,
                                                              "T": .t,
                                                              "U": .u,
                                                              "V": .v,
                                                              "W": .w,
                                                              "X": .x,
                                                              "Y": .y,
                                                              "Z": .z]

    // MARK: Private Type Methods

    private static func _part(for letter: Character) -> ABCPart? {
        partsByLetter[letter]
    }

    private static func _partSequence(in items: [ABC.Importer.Item]) -> ABCPartSequence? {
        for item in items {
            if case let .field(.parts(sequence)) = item {
                return sequence
            }
        }

        return nil
    }

    // MARK: Private Instance Methods

    // A single linear play/skip walk over one segment (no nesting — standard
    // ABC doesn't nest repeats), ported from `RepeatExpander._expandRepeats`.
    // See that type's own comment for the hand-traced derivation of this
    // walk against the §4.9/§4.10 spec examples.
    private func _expandedRepeatRanges(_ range: Range<Int>) throws(ABC.Error) -> [Range<Int>] {
        var result: [Range<Int>] = []
        var index = range.lowerBound
        var loopStart = range.lowerBound
        var pass: UInt = 1
        var skipping = false
        var sawVariantEndingThisPass = false
        var runStart: Int?

        func keep(_ atIndex: Int) {
            if runStart == nil {
                runStart = atIndex
            }
        }

        func flush(upTo end: Int) {
            if let start = runStart, start < end {
                result.append(start..<end)
            }

            runStart = nil
        }

        // A malformed/adversarial ending range (e.g. `[1-999999]`) would
        // otherwise spin this walk that many times; nothing else in the
        // model bounds pass count once an ending block is involved.
        func advancePassOrTerminate() throws(ABC.Error) {
            pass += 1

            guard pass <= 1_000
            else { throw ABC.Error.unbalancedRepeat("repeat/variant-ending expansion exceeded the 1000-pass safety cap") }
        }

        func resetConstruct(to newIndex: Int) {
            loopStart = newIndex
            pass = 1
            skipping = false
            sawVariantEndingThisPass = false
        }

        while index < range.upperBound {
            switch items[index] {
            case let .symbol(.variantEnding(variantEnding)):
                flush(upTo: index)
                skipping = !variantEnding.endings.contains { $0.contains(pass) }
                sawVariantEndingThisPass = true
                index += 1

            case let .symbol(.barLine(barLine)) where barLine.kind == .repeat && barLine.precedingPlayCount.uintValue == 1:
                // A pure opener (e.g. `|:`) — by `ABCBarLine`'s own init
                // this never doubles as a closer.
                if !skipping {
                    keep(index)
                }

                flush(upTo: index + 1)
                loopStart = index + 1
                index += 1

            case let .symbol(.barLine(barLine)) where barLine.kind == .repeat:
                if skipping {
                    // This closer belongs to an ending block that isn't
                    // playing this pass: pass over silently.
                    index += 1
                    skipping = false
                    sawVariantEndingThisPass = false
                    continue
                }

                keep(index)
                flush(upTo: index + 1)

                let terminal: Bool

                if sawVariantEndingThisPass {
                    // An individual closer's play count in an ending chain
                    // is not authoritative.
                    try advancePassOrTerminate()
                    terminal = false
                } else if pass < barLine.precedingPlayCount.uintValue {
                    // The only place a closer's own play count is
                    // authoritative: a plain repeat with no numbered
                    // endings at all.
                    try advancePassOrTerminate()
                    terminal = false
                } else {
                    terminal = true
                }

                if terminal {
                    index += 1
                    resetConstruct(to: index)
                } else {
                    index = loopStart
                    skipping = false
                    sawVariantEndingThisPass = false
                }

            case .symbol(.barLine):
                // Any other bar line (plain/double/end/invisible) ends the
                // construct here, regardless of `skipping` state.
                if !skipping {
                    keep(index)
                }

                flush(upTo: index + 1)
                index += 1
                resetConstruct(to: index)

            default:
                if !skipping {
                    keep(index)
                }

                index += 1
            }
        }

        flush(upTo: range.upperBound)

        return result
    }
}
