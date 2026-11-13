// © 2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import IvorModel
import IvorTiming
import Testing

struct ExportBarTests {
}

// MARK: -

extension ExportBarTests {
    @Test
    func end_isStartPlusLength() {
        let bar = ExportBar(extras: nil,
                            isMeterWritten: true,
                            isPickup: false,
                            length: dur(3, 4),
                            meter: meter("3/4"),
                            start: beat(2))

        #expect(bar.end == beat(11, 4))
    }

    @Test
    func end_pickupBar() {
        let bar = ExportBar(extras: nil,
                            isMeterWritten: true,
                            isPickup: true,
                            length: dur(1, 4),
                            meter: meter("4/4"),
                            start: .zero)

        #expect(bar.end == beat(1, 4))
    }
}
