// © 2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import IvorModel
import IvorTiming
import Testing
import XestiNumbers
import XestiTools

struct DynamicShapeTests {
}

// MARK: -

extension DynamicShapeTests {
    @Test
    func shapes_emptyMap_isEmpty() {
        #expect(summary(DynamicMap<BeatTime>()).isEmpty)
    }

    @Test
    func shapes_flatRepeats_markOnlyTheFirst() {
        #expect(summary(map([(0, .mf), (4, .mf), (8, .mf)])) == ["mark 0 mf"])
    }

    @Test
    func shapes_loneEntry_isMark() {
        #expect(summary(map([(0, .p)])) == ["mark 0 p"])
    }

    @Test
    func shapes_markExtra_survivesFlatPair() {
        var dynamicMap = map([(0, .p)])

        dynamicMap.insert(time: BeatTime(4),
                          dynamic: .p,
                          extras: Extras(elements: [Extra(name: Extra.dynamicMark.name, values: [.string("sfz")])]))
        dynamicMap.insert(time: BeatTime(8),
                          dynamic: .p)

        #expect(summary(dynamicMap) == ["mark 0 p", "mark 4 p sfz"])
    }

    @Test
    func shapes_rampAfterLeadingEntry_staysRamp() {
        #expect(summary(map([(0, .p), (0, .p), (4, .p), (8, .f)])) == ["mark 0 p", "ramp 4 p 8 f"])
    }

    @Test
    func shapes_stepAfterLeadingEntry_isMark() {
        #expect(summary(map([(0, .p), (4, .p), (4, .f)])) == ["mark 0 p", "mark 4 f"])
    }

    @Test
    func shapes_stepOfSeveralEntries_isOneMarkAtTheLastLevel() {
        #expect(summary(map([(0, .p), (4, .p), (4, .mf), (4, .f), (8, .f)])) == ["mark 0 p", "mark 4 f"])
    }

    // MARK: Private

    private func beat(_ time: BeatTime) -> String {
        [(BeatTime(0), "0"), (BeatTime(4), "4"), (BeatTime(8), "8")].first { $0.0 == time }?.1 ?? "?"
    }

    private func map(_ entries: [(Number, Dynamic)]) -> DynamicMap<BeatTime> {
        var dynamicMap = DynamicMap<BeatTime>()

        for (time, dynamic) in entries {
            dynamicMap.insert(time: BeatTime(time),
                              dynamic: dynamic)
        }

        return dynamicMap
    }

    private func name(_ dynamic: Dynamic) -> String {
        [(Dynamic.p, "p"), (.mf, "mf"), (.f, "f"), (.ff, "ff")].first { $0.0 == dynamic }?.1 ?? "?"
    }

    private func summary(_ dynamicMap: DynamicMap<BeatTime>) -> [String] {
        DynamicShape.shapes(of: dynamicMap).map {
            switch $0 {
            case let .mark(time, dynamic, mark):
                "mark \(beat(time)) \(name(dynamic))" + (mark.map { " \($0)" } ?? "")

            case let .ramp(start, startDynamic, end, endDynamic):
                "ramp \(beat(start)) \(name(startDynamic)) \(beat(end)) \(name(endDynamic))"
            }
        }
    }
}
