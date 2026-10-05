// © 2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import Testing

struct InfoFunctionsTests {
}

// MARK: -

extension InfoFunctionsTests {
    @Test
    func describeDedication_labelsText() {
        #expect(describeDedication("To my teacher") == "dedication: To my teacher")
    }

    @Test
    func parseDedicationText_emptyAfterLabel_isNil() {
        #expect(parseDedicationText("dedication:   ") == nil)
    }

    @Test
    func parseDedicationText_ignoresCaseAndSurroundingWhitespace() {
        #expect(parseDedicationText("  DEDICATION:  For Anna \n") == "For Anna")
    }

    @Test
    func parseDedicationText_otherText_isNil() {
        #expect(parseDedicationText("history: Written at dawn") == nil)
        #expect(parseDedicationText("A dedication: of sorts") == nil)
    }

    @Test
    func parseDedicationText_readsDescribedDedication() {
        #expect(parseDedicationText(describeDedication("To my teacher\nwith thanks")) == "To my teacher\nwith thanks")
    }
}
