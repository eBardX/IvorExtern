// © 2026 John Gary Pusey (see LICENSE.md)

internal import IvorABC
internal import IvorModel
internal import IvorTiming
internal import IvorTuning

extension ABC.Exporter {

    // MARK: Internal Nested Types

    // What a reader takes a bare note to be at a point in a voice: the key
    // signature in force, overridden by any accidental written earlier in
    // the bar. It starts in the key signature the `K:` header field writes
    // (the table's entry at time 0, or none, for `K:C`), and hands out an
    // inline `[K:…]` field for each later entry as the voice reaches it.
    //
    // ABC 2.1 (§4.6) carries a written accidental to later notes of the same
    // pitch in the bar, while some readers — `ABC.Importer` among them —
    // carry it to every octave of the letter. So a note is written
    // bare only when both readings already give its accidental, and with an
    // explicit accidental (`=` for a natural) otherwise, which both readings
    // then carry.
    internal struct AccidentalState {

        // MARK: Internal Initializers

        internal init(keySignatureTable: KeySignatureTable) {
            let first = keySignatureTable.first.flatMap { $0.beatTime == .zero ? $0 : nil }

            self.keyChanges = keySignatureTable.filter { $0.beatTime > .zero }
            self.keySignature = first?.keySignature
        }

        // MARK: Private Instance Properties

        private var byLetter: [Pitch.Letter: Pitch.Accidental] = [:]
        private var byPitch: [Pitch.Letter: [Int: Pitch.Accidental]] = [:]     // by octave
        private var keyChanges: [KeySignatureTable.Entry]
        private var keySignature: KeySignature?
    }
}

// MARK: -

extension ABC.Exporter.AccidentalState {

    // MARK: Internal Instance Methods

    // `pitch` as a note writes it here: bare if a reader would already take
    // it to have its accidental, otherwise with that accidental, which is
    // then carried through the rest of the bar.
    internal mutating func abcPitch(for pitch: Pitch) throws(ABC.Error) -> ABCPitch {
        let written = try convertToABCPitch(pitch)
        let keyAccidental = keySignature?.accidental(for: pitch.letter) ?? .natural
        let octave = pitch.octave.intValue

        if (byLetter[pitch.letter] ?? keyAccidental) == pitch.accidental,
           (byPitch[pitch.letter]?[octave] ?? keyAccidental) == pitch.accidental {
            return ABCPitch(letter: written.letter,
                            accidental: .omitted,
                            octave: written.octave)
        }

        byLetter[pitch.letter] = pitch.accidental
        byPitch[pitch.letter, default: [:]][octave] = pitch.accidental

        return written
    }

    // The inline `[K:…]` field for each key signature change at or before
    // `beatTime` not yet written. Each brings a new key signature and, as
    // `ABC.Importer` reads it, a fresh start for the bar's accidentals.
    internal mutating func keyChangeSymbols(through beatTime: BeatTime) -> [ABCSymbol] {
        var symbols: [ABCSymbol] = []

        while let entry = keyChanges.first,
              entry.beatTime <= beatTime {
            symbols.append(.inlineField(.key(convertToABCKeySignature(entry.keySignature,
                                                                      mode: stringValue(entry.extras, .keySignatureMode)))))
            keyChanges.removeFirst()
            keySignature = entry.keySignature

            startBar()
        }

        return symbols
    }

    // A bar line: accidentals written in the bar no longer carry.
    internal mutating func startBar() {
        byLetter = [:]
        byPitch = [:]
    }
}
