// © 2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import IvorModel
import IvorTiming
import Testing
import XestiTools

struct MeterFunctionsTests {
}

// MARK: -

extension MeterFunctionsTests {
    @Test
    func exportBars_beforeFirstEntry_countsBackWithAPickup() throws {
        let table = try meterTable([(beat(1), "3/4")])
        let bars = exportBars(table, through: beat(5, 2))

        #expect(exportBarSummary(bars) == ["0+1/4 3/4 pickup", "1/4+3/4", "1+3/4", "7/4+3/4"])
    }

    @Test
    func exportBars_emptyTable_writesWholeNoteBarsOfCommonTime() {
        let bars = exportBars(MeterTable(), through: beat(5, 2))

        #expect(exportBarSummary(bars) == ["0+1 4/4", "1+1", "2+1"])
    }

    @Test
    func exportBars_emptyTableAndNoMusic_writesOneBar() {
        let bars = exportBars(MeterTable(), through: .zero)

        #expect(exportBarSummary(bars) == ["0+1 4/4"])
    }

    @Test
    func exportBars_freeThenMetered_writesOneFreeBar() throws {
        let table = try meterTable([(.zero, "free"), (beat(5, 2), "4/4")])
        let bars = exportBars(table, through: beat(4))

        #expect(exportBarSummary(bars) == ["0+5/2 free", "5/2+1 4/4", "7/2+1"])
    }

    @Test
    func exportBars_meterChange_writesTheNewMeter() throws {
        let table = try meterTable([(.zero, "3/4"), (beat(3, 2), "6/8")])
        let bars = exportBars(table, through: beat(9, 4))

        #expect(exportBarSummary(bars) == ["0+3/4 3/4", "3/4+3/4", "3/2+3/4 6/8"])
    }

    @Test
    func exportBars_pickup_isTheFirstBar() throws {
        let table = try meterTable([(.zero, "3/4")], pickup: dur(1, 4))
        let bars = exportBars(table, through: beat(7, 4))

        #expect(exportBarSummary(bars) == ["0+1/4 3/4 pickup", "1/4+3/4", "1+3/4"])
    }

    @Test
    func exportBars_restart_writesAShortBarButNoMeter() throws {
        let table = try meterTable([(.zero, "4/4"), (beat(3, 4), "4/4")])
        let bars = exportBars(table, through: beat(7, 4))

        #expect(exportBarSummary(bars) == ["0+3/4 4/4", "3/4+1"])
    }

    @Test
    func exportBars_symbolChange_writesTheMeterAgain() throws {
        var table = try meterTable([(.zero, "4/4")])

        try table.insert(beatTime: beat(1),
                         meter: meter("4/4"),
                         extras: meterSymbolExtras("common"))

        let bars = exportBars(table, through: beat(2))

        #expect(exportBarSummary(bars) == ["0+1 4/4", "1+1 4/4"])
        #expect(stringValue(bars[1].extras, .meterSymbol) == "common")
    }

    @Test
    func makeMeterTable_barlinesOnTheGrid_giveOneEntry() {
        let table = makeMeterTable([(.zero, meter("3/4"), nil),
                                    (beat(3, 4), meter("3/4"), nil),
                                    (beat(3, 2), meter("3/4"), nil)])

        #expect(meterSummary(table) == ["0 3/4"])
    }

    @Test
    func makeMeterTable_freeBars_eachStartABar() {
        let table = makeMeterTable([(.zero, .free, nil),
                                    (beat(3, 2), .free, nil)])

        #expect(meterSummary(table) == ["0 free", "3/2 free"])
    }

    @Test
    func makeMeterTable_meterChange_addsAnEntry() {
        let table = makeMeterTable([(.zero, meter("4/4"), nil),
                                    (beat(1), meter("3/4"), nil),
                                    (beat(7, 4), meter("3/4"), nil)])

        #expect(meterSummary(table) == ["0 4/4", "1 3/4"])
    }

    @Test
    func makeMeterTable_noBarlines_givesAnEmptyTable() {
        #expect(makeMeterTable([]).isEmpty)
    }

    @Test
    func makeMeterTable_restart_keepsTheExtrasOfTheEntryItRestarts() {
        let table = makeMeterTable([(.zero, meter("4/4"), meterSymbolExtras("common")),
                                    (beat(1), meter("4/4"), nil),
                                    (beat(7, 4), meter("4/4"), nil)])

        #expect(meterSummary(table) == ["0 4/4", "7/4 4/4"])
        #expect(table.last?.extras == meterSymbolExtras("common"))
    }

    @Test
    func makeMeterTable_sameTime_laterBarlineWins() {
        let table = makeMeterTable([(.zero, meter("4/4"), nil),
                                    (.zero, meter("3/4"), nil)])

        #expect(meterSummary(table) == ["0 3/4"])
    }

    @Test
    func makeMeterTable_shortBarMidPiece_becomesARestart() {
        let table = makeMeterTable([(.zero, meter("4/4"), nil),
                                    (beat(1), meter("4/4"), nil),
                                    (beat(7, 4), meter("4/4"), nil),
                                    (beat(11, 4), meter("4/4"), nil)])

        #expect(meterSummary(table) == ["0 4/4", "7/4 4/4"])
    }

    @Test
    func makeMeterTable_shortFirstBar_becomesThePickup() {
        let table = makeMeterTable([(.zero, meter("3/4"), nil),
                                    (beat(1, 4), meter("3/4"), nil),
                                    (beat(1), meter("3/4"), nil)])

        #expect(meterSummary(table) == ["pickup 1/4", "0 3/4"])
    }

    @Test
    func makeMeterTable_shortFirstBarBeforeAChange_becomesThePickup() {
        let table = makeMeterTable([(.zero, meter("4/4"), nil),
                                    (beat(1, 4), meter("3/4"), nil)])

        #expect(meterSummary(table) == ["pickup 1/4", "0 4/4", "1/4 3/4"])
    }

    @Test
    func makeMeterTable_writtenExtrasOnTheGrid_addAnEntry() {
        let table = makeMeterTable([(.zero, meter("4/4"), nil),
                                    (beat(1), meter("4/4"), meterSymbolExtras("common"))])

        #expect(meterSummary(table) == ["0 4/4", "1 4/4"])
    }
}
