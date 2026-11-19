// © 2026 John Gary Pusey (see LICENSE.md)

internal import IvorModel
internal import IvorMXL
internal import IvorTiming
internal import IvorTuning
internal import XestiTools

// MARK: Internal Type Aliases

// Where `placeMusicXMLKeys(_:in:)` puts each key: by bar index,
// in the opening `<attributes>` of the bar it starts, or by beat time, as
// `<attributes>` of its own in the middle of a bar.
internal typealias MusicXMLKeyPlacement = (barKeys: [Int: MXLKey], midBarKeys: [BeatTime: MXLMusicItem])

// MARK: Internal Functions

// A `<key>`'s key. A traditional key is diatonic, with its `<fifths>`
// folded into −7…+7 and its `<mode>` kept if `Key.Mode(name:)` reads it (no
// `<mode>`, or one it doesn't read, gives no mode); `<mode>none</mode>` is an
// atonal key. A non-traditional key is the key its `<key-step>`/`<key-alter>`
// pairs make: diatonic with no mode if they happen to form a diatonic
// signature, otherwise custom. `nil` if a pair alters a letter by anything
// but −1, 0 or +1 (double and microtonal alterations), or alters one letter
// twice. `<key-octave>` is ignored.
internal func convertToKey(_ key: MXLKey) -> Key? {
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

        return Key(accidentals: accidentals)

    case let .traditionalKey(traditionalKey):
        if traditionalKey.mode?.lowercased() == atonalModeName {
            return .atonal
        }

        return Key.diatonic(fifths: foldedFifths(traditionalKey.fifths.intValue),
                            mode: traditionalKey.mode.flatMap(Key.Mode.init(name:)))
    }
}

// The `<key>` for a key: a traditional key for a diatonic one, with a
// `<mode>` when it has one; `<fifths>0</fifths>` with `<mode>none</mode>`
// for an atonal one; and for a custom one, a non-traditional key with a
// `<key-step>`/`<key-alter>` pair for each accidental, in canonical order
// (flats, then sharps).
internal func convertToMusicXMLKey(_ key: Key) -> MXLKey? {
    switch key {
    case .atonal:
        guard let mxlFifths = MXLFifths(intValue: 0)
        else { return nil }

        return MXLKey(content: .traditionalKey(MXLTraditionalKey(fifths: mxlFifths,
                                                                 mode: atonalModeName)))

    case let .custom(signature):
        let groups = signature.accidentals.map {
            MXLNonTraditionalKey(step: convertToMusicXMLStep($0.letter),
                                 alter: MXLSemitones($0.accidental.order))
        }

        return MXLKey(content: .nonTraditionalKey(groups))

    case let .diatonic(diatonic):
        guard let mxlFifths = MXLFifths(intValue: diatonic.fifths)
        else { return nil }

        return MXLKey(content: .traditionalKey(MXLTraditionalKey(fifths: mxlFifths,
                                                                 mode: diatonic.mode?.rawValue)))
    }
}

// Where each key entry goes among the measures of `bars` (see
// `exportBars(_:through:)`), as a `<key>` (see `convertToMusicXMLKey(_:)`).
// One at a bar's start goes in that bar's opening `<attributes>`, by bar index; one
// in the middle of a bar gets `<attributes>` of its own there, by beat time.
// An empty table gives neither, so no `<key>` is written at all.
internal func placeMusicXMLKeys(_ keyTable: KeyTable,
                                in bars: [ExportBar]) -> MusicXMLKeyPlacement {
    var barKeys: [Int: MXLKey] = [:]
    var midBarKeys: [BeatTime: MXLMusicItem] = [:]

    for entry in keyTable {
        guard let key = convertToMusicXMLKey(entry.key)
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

// MARK: Private Constants

// The `<mode>` an atonal key is written with, and read from.
private let atonalModeName = "none"
