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
        #expect(dynamicShapeSummary(DynamicMap<BeatTime>()).isEmpty)
    }

    @Test
    func shapes_flatRepeats_markOnlyTheFirst() {
        #expect(dynamicShapeSummary(makeDynamicMap([(0, .mf), (4, .mf), (8, .mf)])) == ["mark 0 mf"])
    }

    @Test
    func shapes_loneEntry_isMark() {
        #expect(dynamicShapeSummary(makeDynamicMap([(0, .p)])) == ["mark 0 p"])
    }

    @Test
    func shapes_markExtra_survivesFlatPair() {
        var dynamicMap = makeDynamicMap([(0, .p)])

        dynamicMap.insert(time: BeatTime(4),
                          dynamic: .p,
                          extras: Extras(elements: [Extra(name: Extra.dynamicMark.name, values: [.string("sfz")])]))
        dynamicMap.insert(time: BeatTime(8),
                          dynamic: .p)

        #expect(dynamicShapeSummary(dynamicMap) == ["mark 0 p", "mark 4 p sfz"])
    }

    @Test
    func shapes_rampAfterLeadingEntry_staysRamp() {
        #expect(dynamicShapeSummary(makeDynamicMap([(0, .p), (0, .p), (4, .p), (8, .f)])) == ["mark 0 p", "ramp 4 p 8 f"])
    }

    @Test
    func shapes_stepAfterLeadingEntry_isMark() {
        #expect(dynamicShapeSummary(makeDynamicMap([(0, .p), (4, .p), (4, .f)])) == ["mark 0 p", "mark 4 f"])
    }

    @Test
    func shapes_stepOfSeveralEntries_isOneMarkAtTheLastLevel() {
        #expect(dynamicShapeSummary(makeDynamicMap([(0, .p), (4, .p), (4, .mf), (4, .f), (8, .f)])) == ["mark 0 p", "mark 4 f"])
    }
}
