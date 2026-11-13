// © 2026 John Gary Pusey (see LICENSE.md)

import IvorABC
@testable import IvorExtern
import IvorModel
import Testing
import XestiTools

struct ABCMeterFunctionsTests {
}

// MARK: -

extension ABCMeterFunctionsTests {
    @Test(arguments: [("3/4", "3/4"),
                      ("6/8", "6/8"),
                      ("2+2+3/8", "(2+2+3)/8"),
                      ("free", "none"),
                      ("6/12", "2/4"),
                      ("3/6", "2/4"),
                      ("7/12", "none"),
                      ("4/3", "none"),
                      ("3/128", "none")])
    func convertToABCTimeSignature_meter(_ plain: String,
                                         _ expected: String) {
        #expect(abcTimeSignatureText(convertToABCTimeSignature(meter(plain), nil)) == expected)
    }

    @Test(arguments: [("4/4", "common", "C"),
                      ("2/2", "cut", "C|"),
                      ("2/2", "common", "2/2"),
                      ("8/8", "common", "8/8")])
    func convertToABCTimeSignature_symbol_onlyWhenItMatches(_ plain: String,
                                                            _ symbol: String,
                                                            _ expected: String) {
        let extras = Extras(elements: [Extra(name: Extra.meterSymbol.name,
                                             values: [.string(symbol)])])

        #expect(abcTimeSignatureText(convertToABCTimeSignature(meter(plain), extras)) == expected)
    }

    @Test
    func convertToMeter_complex_keepsItsGroups() throws {
        let additive = try #require(ABCTimeSignature.AdditiveMeter(numerators: [3, 2],
                                                                   denominator: 8))

        #expect(convertToMeter(.complex(additive))?.plain == "3+2/8")
        #expect(convertToMeterExtras(.complex(additive)) == nil)
    }

    @Test(arguments: [(ABCTimeSignature.common, "4/4", String?("common")),
                      (.cut, "2/2", "cut"),
                      (.empty, "free", String?.none)])
    func convertToMeter_timeSignature(_ timeSignature: ABCTimeSignature,
                                      _ plain: String,
                                      _ symbol: String?) {
        #expect(convertToMeter(timeSignature)?.plain == plain)
        #expect(stringValue(convertToMeterExtras(timeSignature), .meterSymbol) == symbol)
    }
}
