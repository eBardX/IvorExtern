// © 2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import Testing
import XestiNumbers

struct MusicXMLDurationTests {
}

// MARK: -

extension MusicXMLDurationTests {
    @Test
    func addAssign() {
        var duration = MusicXML.Duration(numberValue: Number(numerator: 1,
                                                             denominator: 4))

        duration += MusicXML.Duration(numberValue: Number(numerator: 1,
                                                          denominator: 4))

        #expect(duration.numberValue == Number(numerator: 1,
                                               denominator: 2))
    }

    @Test
    func addition() {
        let lhs = MusicXML.Duration(numberValue: Number(numerator: 1,
                                                        denominator: 4))
        let rhs = MusicXML.Duration(numberValue: Number(numerator: 1,
                                                        denominator: 2))

        let result = lhs + rhs

        #expect(result.numberValue == Number(numerator: 3,
                                             denominator: 4))
    }

    @Test
    func comparable() {
        let smaller = MusicXML.Duration(numberValue: Number(numerator: 1,
                                                            denominator: 4))
        let larger = MusicXML.Duration(numberValue: Number(numerator: 1,
                                                           denominator: 2))

        #expect(smaller < larger)
        #expect(!(larger < smaller))
    }

    @Test
    func equality() {
        let lhs = MusicXML.Duration(numberValue: Number(numerator: 1,
                                                        denominator: 4))
        let rhs = MusicXML.Duration(numberValue: Number(numerator: 1,
                                                        denominator: 4))
        let other = MusicXML.Duration(numberValue: Number(numerator: 1,
                                                          denominator: 2))

        #expect(lhs == rhs)
        #expect(lhs != other)
    }

    @Test
    func hashable() {
        let lhs = MusicXML.Duration(numberValue: Number(numerator: 1,
                                                        denominator: 4))
        let rhs = MusicXML.Duration(numberValue: Number(numerator: 1,
                                                        denominator: 4))

        #expect(Set([lhs, rhs]).count == 1)
    }

    @Test
    func init_numberValue() {
        let duration = MusicXML.Duration(numberValue: Number(numerator: 3,
                                                             denominator: 8))

        #expect(duration.numberValue == Number(numerator: 3,
                                               denominator: 8))
    }

    @Test
    func subtracting_negativeResultReturnsNil() {
        let lhs = MusicXML.Duration(numberValue: Number(numerator: 1,
                                                        denominator: 4))
        let rhs = MusicXML.Duration(numberValue: Number(numerator: 1,
                                                        denominator: 2))

        #expect(MusicXML.Duration.subtracting(lhs, rhs) == nil)
    }

    @Test
    func subtracting_validResult() {
        let lhs = MusicXML.Duration(numberValue: Number(numerator: 3,
                                                        denominator: 4))
        let rhs = MusicXML.Duration(numberValue: Number(numerator: 1,
                                                        denominator: 4))

        let result = MusicXML.Duration.subtracting(lhs, rhs)

        #expect(result?.numberValue == Number(numerator: 1,
                                              denominator: 2))
    }

    @Test
    func zero() {
        #expect(MusicXML.Duration.zero.numberValue == 0)
    }
}
