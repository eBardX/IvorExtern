// © 2026 John Gary Pusey (see LICENSE.md)

private import IvorMusicXML

// The measure-visit order for one score: a list of measure indices, honoring
// repeats (with `times`), numbered `<ending>`s played only on their pass, and
// a single `da capo`/`dal segno` jump respecting `fine`/`toCoda`. Ported from
// upstream's own play-order walk plus its measure-grid reconstruction, but
// built directly from the AST rather than reconstructed from a resolved,
// onset-flattened timeline — walking the AST, the measures are still there,
// so the measure grid shrinks to a per-index marker scan (see
// `_measures(_:)`) with no onset bookkeeping.
//
// A deliberate simplification from upstream's onset-boundary disambiguation:
// every barline- or `<sound>`-carried marker (repeat, ending, segno, coda,
// `da capo`/`dal segno`/`fine`) is attributed to whichever measure's own item
// list contains it, regardless of the barline's `location` attribute. This
// matches standard MusicXML authoring — a forward repeat or a segno/coda
// target is written with `location="left"` as the first item of the measure
// it opens; a backward repeat, an ending stop, or a `da capo`/`fine` trigger
// is written with `location="right"` as the last item of the measure it
// closes — so both cases already read naturally as "the measure containing
// the element."
extension MusicXML.Importer {

    internal struct Plan {

        // MARK: Internal Initializers

        internal init(_ score: MusicXML.Score) throws(MusicXML.Error) {
            self.order = try Self._playOrder(Self._measures(score))
        }

        // MARK: Internal Instance Properties

        internal let order: [Int]

        // MARK: Private Nested Types

        // One measure's navigation markers, gathered by index across every
        // part (a repeat or ending is often only marked in one part, but
        // applies to the whole score).
        private struct Measure {
            fileprivate var closesRepeat: Int?
            fileprivate var coda: String?
            fileprivate var dalsegno: String?
            fileprivate var endingNumbers: [Int]?
            fileprivate var endingStops = false
            fileprivate var isDaCapo = false
            fileprivate var isFine = false
            fileprivate var opensRepeat = false
            fileprivate var segno: String?
            fileprivate var toCoda: String?
        }

        // The running state of the play-order walk: the current measure
        // `index`, the `loopStart` a backward repeat returns to, the current
        // `pass` through the active repeat span (also the `<ending>`
        // selector), whether an ending is being skipped this pass, and
        // whether a `da capo`/`dal segno` jump is in progress (which
        // suppresses further repeats and jumps).
        private struct Walk {
            fileprivate var index = 0
            fileprivate var inJump = false
            fileprivate var loopStart = 0
            fileprivate var pass = 1
            fileprivate var skipEnding = false
        }
    }
}

// MARK: -

extension MusicXML.Importer.Plan {

    // MARK: Private Type Methods

    // Advances past a just-played measure, applying its repeat and
    // navigation markers. Returns `true` when the walk should stop (a `fine`
    // reached during a jump).
    private static func _advance(after measure: Measure,
                                 in measures: [Measure],
                                 _ state: inout Walk) -> Bool {
        if !state.inJump,
           measure.opensRepeat {
            state.loopStart = state.index
        }

        if measure.endingStops {
            state.skipEnding = false
        }

        if !state.inJump,
           measure.isDaCapo || measure.dalsegno != nil {
            state.inJump = true
            state.pass = 1
            state.index = measure.isDaCapo ? 0 : (_index(segno: measure.dalsegno, in: measures) ?? 0)

            return false
        }

        if state.inJump {
            if measure.isFine {
                return true
            }

            if let coda = _index(coda: measure.toCoda, in: measures) {
                state.index = coda

                return false
            }
        }

        _closeRepeat(after: measure, &state)

        return false
    }

    private static func _apply(_ barline: MXLBarline,
                               to measure: inout Measure) {
        if barline.repeat?.direction == .forward {
            measure.opensRepeat = true
        }

        if barline.repeat?.direction == .backward {
            measure.closesRepeat = barline.repeat?.times ?? 2
        }

        if barline.ending?.kind == .start {
            measure.endingNumbers = barline.ending?.number
        }

        if let kind = barline.ending?.kind,
           kind == .stop || kind == .discontinue {
            measure.endingStops = true
        }

        if barline.segno != nil || barline.segnoAttribute != nil {
            measure.segno = barline.segnoAttribute ?? ""
        }

        if barline.coda != nil || barline.codaAttribute != nil {
            measure.coda = barline.codaAttribute ?? ""
        }
    }

    private static func _apply(_ sound: MXLSound,
                               to measure: inout Measure) {
        if let segno = sound.segno {
            measure.segno = segno
        }

        if let coda = sound.coda {
            measure.coda = coda
        }

        if sound.isDaCapo == true {
            measure.isDaCapo = true
        }

        if let dalsegno = sound.dalsegno {
            measure.dalsegno = dalsegno
        }

        if let toCoda = sound.tocoda {
            measure.toCoda = toCoda
        }

        if sound.fine != nil {
            measure.isFine = true
        }
    }

    // Applies a backward repeat: loops to the span start until its `times`
    // are exhausted, then falls through to the next measure.
    private static func _closeRepeat(after measure: Measure,
                                     _ state: inout Walk) {
        guard !state.inJump,
              let times = measure.closesRepeat
        else {
            state.index += 1

            return
        }

        guard state.pass < times
        else {
            state.pass = 1
            state.loopStart = state.index + 1
            state.index += 1

            return
        }

        state.pass += 1
        state.skipEnding = false
        state.index = state.loopStart
    }

    private static func _index(coda name: String?,
                               in measures: [Measure]) -> Int? {
        guard let name
        else { return nil }

        return measures.firstIndex { $0.coda == name }
            ?? measures.firstIndex { $0.coda != nil }
    }

    private static func _index(segno name: String?,
                               in measures: [Measure]) -> Int? {
        measures.firstIndex { $0.segno == name }
            ?? measures.firstIndex { $0.segno != nil }
    }

    // Gathers each measure index's navigation markers across every part.
    private static func _measures(_ score: MusicXML.Score) -> [Measure] {
        let count = score.parts.map(\.measures.count).max() ?? 0
        var measures = Array(repeating: Measure(), count: count)

        for part in score.parts {
            for (index, sourceMeasure) in part.measures.enumerated() {
                for item in sourceMeasure.items {
                    switch item {
                    case let .barline(barline):
                        _apply(barline, to: &measures[index])

                    case let .direction(direction):
                        if let sound = direction.sound {
                            _apply(sound, to: &measures[index])
                        }

                    case let .sound(sound):
                        _apply(sound, to: &measures[index])

                    default:
                        break
                    }
                }
            }
        }

        return measures
    }

    // The linear play/skip walk over the measure grid. Bounded by a generous
    // step cap so a malformed structure terminates rather than spins.
    private static func _playOrder(_ measures: [Measure]) throws(MusicXML.Error) -> [Int] {
        let cap = max(10_000, measures.count * 100)

        var order: [Int] = []
        var state = Walk()
        var steps = 0

        while state.index < measures.count {
            steps += 1

            guard steps <= cap
            else { throw MusicXML.Error.unbalancedRepeat("repeat/ending unfolding exceeded the safety cap") }

            let measure = measures[state.index]

            if _skips(measure, &state) {
                continue
            }

            order.append(state.index)

            if _advance(after: measure, in: measures, &state) {
                break
            }
        }

        return order
    }

    // Applies a measure's `<ending>` markers to the skip flag and, when the
    // measure is in an ending not played this pass, steps over it. Returns
    // `true` when the measure was skipped.
    private static func _skips(_ measure: Measure,
                               _ state: inout Walk) -> Bool {
        if !state.inJump,
           let numbers = measure.endingNumbers {
            state.skipEnding = !(numbers.isEmpty || numbers.contains(state.pass))
        }

        guard state.skipEnding
        else { return false }

        if measure.endingStops {
            state.skipEnding = false
        }

        state.index += 1

        return true
    }
}
