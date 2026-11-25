// © 2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import IvorModel
import IvorTiming
import Testing
import XestiNumbers
import XestiTools

struct FermataMarkPlacementsTests {
}

// MARK: -

extension FermataMarkPlacementsTests {
    @Test
    func init_dropsCaesurasStrayMarksAndExecutions() throws {
        var markTable = PartMarkTable<BeatTime>()
        let stretch = try #require(FermataStretch(numberValue: 2))
        let held = Fermata<BeatTime>(execution: FermataExecution(hold: .stretch(stretch)))

        markTable.insert(time: beat(1, 8), mark: .caesura(nil))
        try markTable.insert(time: beat(1, 8), mark: .fermata(Fermata(), span: #require(PositiveDuration(dur(1, 16)))))
        try markTable.insert(time: 0, mark: .fermata(held, span: #require(PositiveDuration(dur(1, 4)))))

        var reported: [ExternWarning.Kind] = []
        let placements = FermataMarkPlacements(markTable,
                                               sliceStarts: [0, beat(1, 4)],
                                               barTimes: []) { reported.append($0) }

        #expect(placements.atStart == [0: held])
        #expect(placements.beforeBar.isEmpty)
        #expect(reported.sorted { $0.rawValue < $1.rawValue } == [.droppedCaesura, .droppedExecution, .droppedFermata])
    }

    @Test
    func init_placesEachMarkBeforeItsBarLineOrAtItsStart() throws {
        var markTable = PartMarkTable<BeatTime>()
        let short = Fermata<BeatTime>(shape: .short)

        try markTable.insert(time: beat(3, 4), mark: .fermata(Fermata(), span: #require(PositiveDuration(dur(1, 4)))))
        try markTable.insert(time: beat(5, 4), mark: .fermata(short, span: #require(PositiveDuration(dur(1, 4)))))

        var reported: [ExternWarning.Kind] = []
        let placements = FermataMarkPlacements(markTable,
                                               sliceStarts: [0, beat(3, 4), beat(5, 4)],
                                               barTimes: [beat(1, 1)]) { reported.append($0) }

        #expect(placements.beforeBar == [beat(1, 1): Fermata()])
        #expect(placements.atStart == [beat(5, 4): short])
        #expect(reported.isEmpty)
    }
}
