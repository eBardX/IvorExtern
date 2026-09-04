// © 2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import IvorJohnnySonic
import Testing

struct JohnnySonicImporterTuningTests {
}

// MARK: -

extension JohnnySonicImporterTuningTests {
    @Test
    func frequency_defaultTuning() {
        let tuning = JohnnySonic.Importer.Tuning([])

        let frequency = tuning.frequency(forPitch: 0)

        #expect(abs(frequency - 8.175798912) < 0.00000001)
    }

    @Test
    func frequency_negativePitch_returnsAbsoluteValue() {
        let tuning = JohnnySonic.Importer.Tuning([])

        let frequency = tuning.frequency(forPitch: -440)

        #expect(frequency == 440)
    }

    @Test
    func frequency_positivePitch_middleC() {
        let tuning = JohnnySonic.Importer.Tuning([])

        let frequency = tuning.frequency(forPitch: 60)

        #expect(abs(frequency - 261.625565) < 0.0001)
    }

    @Test
    func frequency_withAppliedTuning() {
        let dkmTuning = DKMTuning(primaryInterval: 2,
                                  notesPerInterval: 12,
                                  pitchConvExponent: 3,
                                  pitchConvFactor: 1.021974864)
        let tuning = JohnnySonic.Importer.Tuning([.tuning(dkmTuning)])

        let frequency = tuning.frequency(forPitch: 0)

        #expect(abs(frequency - 8.175798912) < 0.00000001)
    }

    @Test
    func init_ignoresNonTuningCommands() {
        let tuning = JohnnySonic.Importer.Tuning([.end, .comment("a comment")])

        let frequency = tuning.frequency(forPitch: 0)

        #expect(abs(frequency - 8.175798912) < 0.00000001)
    }

    @Test
    func init_lastValidTuning_replacesEarlierOne() {
        let first = DKMTuning(primaryInterval: 2,
                              notesPerInterval: 24,
                              pitchConvExponent: 3,
                              pitchConvFactor: 1.021974864)
        let second = DKMTuning(primaryInterval: 2,
                               notesPerInterval: 12,
                               pitchConvExponent: 3,
                               pitchConvFactor: 1.021974864)
        let tuning = JohnnySonic.Importer.Tuning([.tuning(first), .tuning(second)])

        let frequency = tuning.frequency(forPitch: 12)

        #expect(abs(frequency - 16.351597824) < 0.00000001)
    }

    @Test
    func init_outOfRangeFields_areIgnored() {
        let dkmTuning = DKMTuning(primaryInterval: 1,
                                  notesPerInterval: 1,
                                  pitchConvExponent: 0,
                                  pitchConvFactor: 0)
        let tuning = JohnnySonic.Importer.Tuning([.tuning(dkmTuning)])

        let frequency = tuning.frequency(forPitch: 0)

        #expect(abs(frequency - 8.175798912) < 0.00000001)
    }
}
