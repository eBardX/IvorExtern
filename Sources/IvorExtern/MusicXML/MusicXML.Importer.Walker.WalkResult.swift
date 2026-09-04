// © 2026 John Gary Pusey (see LICENSE.md)

internal import IvorModel
internal import IvorTiming

extension MusicXML.Importer.Walker {

    // The pan, tempo, and notated-dynamics events a part's `<sound>`/
    // `<direction>` elements produced, gathered alongside the part's
    // resolved voices — one instance per MusicXML part. Each voice's own
    // note-level dynamics travel with it instead, as `MusicXML.Voice`'s own
    // `noteDynamicEvents` — see that type's doc comment. A struct, not a
    // plain tuple, purely to stay under SwiftLint's `large_tuple` limit at
    // four members.
    internal struct WalkResult {

        // MARK: Internal Instance Properties

        internal let directionDynamicEvents: [MusicXML.Importer.Context.DynamicEvent]
        internal let panEvents: [(beatTime: BeatTime, pan: Pan)]
        internal let part: MusicXML.Part
        internal let tempoEvents: [(beatTime: BeatTime, tempo: Tempo)]
    }
}
