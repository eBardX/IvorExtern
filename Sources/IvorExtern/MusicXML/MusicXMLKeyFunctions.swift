// © 2026 John Gary Pusey (see LICENSE.md)

internal import IvorModel
internal import IvorMXL
internal import IvorTiming
internal import IvorTuning
internal import XestiTools

// MARK: Internal Type Aliases

// Where `placeMusicXMLKeys(_:in:)` puts each key signature: by bar index,
// in the opening `<attributes>` of the bar it starts, or by beat time, as
// `<attributes>` of its own in the middle of a bar.
internal typealias MusicXMLKeyPlacement = (barKeys: [Int: MXLKey], midBarKeys: [BeatTime: MXLMusicItem])

// MARK: Internal Functions

// A `<key>`'s key signature and mode name. A traditional key is diatonic,
// with its `<fifths>` folded into −7…+7 and its `<mode>` kept if it's one the
// formats share; `mode none` gives the same signature with mode "none".
// A non-traditional key is the signature its `<key-step>`/`<key-alter>`
// pairs alter, which is diatonic if they happen to form one (such a key has
// no mode). `nil` if a pair alters a letter by anything but −1, 0 or +1
// (double and microtonal alterations), or alters one letter twice.
// `<key-octave>` is ignored.
internal func convertToKeySignature(_ key: MXLKey) -> (keySignature: KeySignature, mode: String?)? {
    switch key.content {
    case let .nonTraditionalKey(groups):
        var accidentals: [PitchClass] = []

        for group in groups {
            let accidental: Pitch.Accidental

            switch group.alter {
            case -1:
                accidental = .flat

            case 0:
                accidental = .natural

            case 1:
                accidental = .sharp

            default:
                return nil
            }

            accidentals.append(PitchClass(letter: convertToPitchLetter(group.step),
                                          accidental: accidental))
        }

        return KeySignature(accidentals: accidentals).map { ($0, nil) }

    case let .traditionalKey(traditionalKey):
        return diatonicKeySignature(fifths: traditionalKey.fifths.intValue).map {
            ($0, traditionalKey.mode.flatMap(keySignatureModeName))
        }
    }
}

// The `<key>` for a key signature: a traditional key, with `<mode>` from
// `mode` when there is one, for a diatonic signature; for a custom one, a
// non-traditional key with a `<key-step>`/`<key-alter>` pair for each
// accidental, in canonical order (flats, then sharps).
internal func convertToMusicXMLKey(_ keySignature: KeySignature,
                                   mode: String?) -> MXLKey? {
    if let fifths = keySignature.fifths {
        guard let mxlFifths = MXLFifths(intValue: fifths)
        else { return nil }

        return MXLKey(content: .traditionalKey(MXLTraditionalKey(fifths: mxlFifths,
                                                                 mode: mode)))
    }

    let groups = keySignature.accidentals.map {
        MXLNonTraditionalKey(step: convertToMusicXMLStep($0.letter),
                             alter: MXLSemitones($0.accidental.order))
    }

    return MXLKey(content: .nonTraditionalKey(groups))
}

// Where each key signature entry goes among the measures of `bars` (see
// `exportBars(_:through:)`), as a `<key>` (see
// `convertToMusicXMLKey(_:mode:)`), with its mode for a diatonic one. One at
// a bar's start goes in that bar's opening `<attributes>`, by bar index; one
// in the middle of a bar gets `<attributes>` of its own there, by beat time.
// An empty table gives neither, so no `<key>` is written at all.
internal func placeMusicXMLKeys(_ keySignatureTable: KeySignatureTable,
                                in bars: [ExportBar]) -> MusicXMLKeyPlacement {
    var barKeys: [Int: MXLKey] = [:]
    var midBarKeys: [BeatTime: MXLMusicItem] = [:]

    for entry in keySignatureTable {
        guard let key = convertToMusicXMLKey(entry.keySignature,
                                             mode: stringValue(entry.extras, .keySignatureMode))
        else { continue }

        if let barIndex = bars.firstIndex(where: { $0.start == entry.beatTime }) {
            barKeys[barIndex] = key
        } else {
            midBarKeys[entry.beatTime] = .attributes(MXLAttributes(key: [key],
                                                                   content: .transpose([])))
        }
    }

    return (barKeys, midBarKeys)
}
