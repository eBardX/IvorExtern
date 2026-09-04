// © 2026 John Gary Pusey (see LICENSE.md)

internal import Foundation
internal import IvorJohnnySonic

extension JohnnySonic.Importer {

    // Transcribes `ProcessTuning`/`ConvertPitchToFreq` from DKM's main.c. A
    // `/Tuning` command replaces only the fields the reference accepts as
    // in-range, leaving the rest at their previous value.
    internal struct Tuning {

        // MARK: Internal Initializers

        internal init(_ commands: [JohnnySonic.Command]) {
            self.notesPerInterval = 12.0
            self.pitchConvExponent = 3.0
            self.pitchConvFactor = 1.021974864
            self.primaryInterval = 2.0

            for command in commands {
                guard case let .tuning(tuning) = command
                else { continue }

                _apply(tuning)
            }
        }

        // MARK: Private Instance Properties

        private var notesPerInterval: Double
        private var pitchConvExponent: Double
        private var pitchConvFactor: Double
        private var primaryInterval: Double
    }
}

// MARK: -

extension JohnnySonic.Importer.Tuning {

    // MARK: Internal Instance Methods

    // A negative pitch is a literal frequency in Hz — see
    // `convertToJohnnySonicPitch(_ frequency:)` on the export side, which
    // uses the same convention in reverse. Only a non-negative pitch runs
    // through the tuning formula.
    internal func frequency(forPitch pitch: Double) -> Double {
        guard pitch >= 0
        else { return abs(pitch) }

        return pow(primaryInterval, pitch / notesPerInterval + pitchConvExponent) * pitchConvFactor
    }

    // MARK: Private Instance Methods

    private mutating func _apply(_ tuning: DKMTuning) {
        if tuning.notesPerInterval > 1 {
            notesPerInterval = tuning.notesPerInterval
        }

        if tuning.pitchConvExponent > 0 {
            pitchConvExponent = tuning.pitchConvExponent
        }

        if tuning.pitchConvFactor > 0 {
            pitchConvFactor = tuning.pitchConvFactor
        }

        if tuning.primaryInterval > 1 {
            primaryInterval = tuning.primaryInterval
        }
    }
}
