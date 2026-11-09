// © 2026 John Gary Pusey (see LICENSE.md)

internal import IvorModel
internal import IvorTiming

extension MusicXML.Importer.Walker {

    // MARK: Internal Nested Types

    // The pan, pedal, tempo, and notated-dynamics events a part's `<sound>`/
    // `<direction>` elements produced, gathered alongside the part's
    // resolved voices — one instance per MusicXML part. Each voice's own
    // note-level dynamics travel with it instead, as `MusicXML.Voice`'s own
    // `noteDynamicEvents` — see that type's doc comment. A struct, not a
    // plain tuple, purely to stay under SwiftLint's `large_tuple` limit.
    internal struct WalkResult {

        // MARK: Internal Instance Properties

        internal let directionDynamicEvents: [MusicXML.Importer.Context.DynamicEvent]
        internal let panEvents: [(beatTime: BeatTime, pan: Pan)]
        internal let part: MusicXML.Part
        internal let pedalEvents: [(beatTime: BeatTime, pedal: Pedal, level: Pedal.Level)]
        internal let tempoEvents: [(beatTime: BeatTime, tempo: Tempo)]
    }
}
