// © 2026 John Gary Pusey (see LICENSE.md)

internal import IvorGMN
internal import IvorTuning

// MARK: Internal Functions

// The `\key` tag for a key signature. A diatonic signature in major or minor
// is written as its key name, as guidolib reads one: the tonic's letter,
// uppercase for major and lowercase for minor, then `#` or `&` for a sharp or
// flat tonic (`\key<"D">`, `\key<"e&">`). Any other diatonic signature is
// written as its number of fifths (`\key<2>`). A custom signature is written
// as a free key, every note with its own accidental, in canonical order
// (`\key<"free=b&f#">`), so its meaning doesn't depend on guidolib's running
// accidentals.
internal func convertToGMNKey(_ keySignature: KeySignature,
                              mode: String?) -> GMNKey {
    guard let fifths = keySignature.fifths
    else {
        let spec = keySignature.accidentals.map { pitchClass in
            "\(pitchClass.letter)".lowercased() + (pitchClass.accidental == .flat ? "&" : "#")
        }

        return GMNKey(key: .name("free=" + spec.joined()))
    }

    guard mode == "major" || mode == "minor",
          let tonic = tonic(of: keySignature, mode: mode)
    else { return GMNKey(key: .number(fifths)) }

    let letter = "\(tonic.letter)"
    let name = (mode == "minor" ? letter.lowercased() : letter.uppercased()) + _guidoAccidental(tonic.accidental)

    return GMNKey(key: .name(name))
}

// A `\key` tag's key signature and mode name, read as guidolib's `ARKey`
// reads it. A number is that many sharps (or flats), folded into −7…+7, with
// no mode. A name is a key: its first letter the tonic (`H` or `B` for B),
// uppercase for major and lowercase for minor, and a second character of `#`
// or `&` raising or lowering it. An empty name is C major, and an unknown
// letter C major too, as guidolib takes them. A name starting `free=`, or a
// `free` parameter, is a free key (see `_parseFreeKey(_:)`). `nil` for a free
// key that needs a double or microtonal alteration.
internal func convertToKeySignature(_ key: GMNKey) -> (keySignature: KeySignature, mode: String?)? {
    if let free = key.free {
        return _parseFreeKey(free).map { ($0, nil) }
    }

    switch key.key {
    case let .name(name):
        if name.hasPrefix(freePrefix) {
            return _parseFreeKey(String(name.dropFirst(freePrefix.count))).map { ($0, nil) }
        }

        return _parseKeyName(name)

    case let .number(fifths):
        return diatonicKeySignature(fifths: fifths).map { ($0, nil) }
    }
}

// MARK: Private Constants

private let freePrefix = "free="

private let keyNameFifths: [Character: Int] = ["A": 3,
                                               "B": 5,
                                               "C": 0,
                                               "D": 2,
                                               "E": 4,
                                               "F": -1,
                                               "G": 1,
                                               "H": 5]

private let letters: [String: Pitch.Letter] = ["a": .a,
                                               "b": .b,
                                               "c": .c,
                                               "d": .d,
                                               "e": .e,
                                               "f": .f,
                                               "g": .g,
                                               "h": .b,
                                               "do": .c,
                                               "fa": .f,
                                               "la": .a,
                                               "mi": .e,
                                               "re": .d,
                                               "si": .b,
                                               "so": .g,
                                               "sol": .g,
                                               "ti": .b,
                                               "ut": .c]

// guidolib reads these names in a free key but has no letter for them, so
// they're skipped.
private let skippedNames: Set<String> = ["ais", "cis", "dis", "fis", "gis"]

// MARK: Private Functions

private func _guidoAccidental(_ accidental: Pitch.Accidental) -> String {
    switch accidental {
    case .flat:
        "&"

    case .sharp:
        "#"

    default:
        ""
    }
}

// A free key's specification, as guidolib's `ARKey::getFreeKeyArray` reads
// it: note names, each optionally followed by an accidental (a run of `#`
// or `&`, or a number of semitones in brackets, `[1.5]`) and an octave
// (ignored). A note with no accidental (or a zero one) takes the one before
// it ("running accidentals"), so `b& e a` is B♭, E♭ and A♭. Reading stops at an unknown
// name. `nil` if an alteration is anything but −1, 0 or +1 semitones, or a
// letter comes twice.
private func _parseFreeKey(_ spec: String) -> KeySignature? {
    var accidentals: [PitchClass] = []
    var current = 0.0
    var remaining = Substring(spec)

    while true {
        remaining = remaining.drop { $0 == " " || $0 == "\t" }

        let name = String(remaining.prefix { $0.isLetter }).lowercased()

        remaining = remaining.dropFirst(name.count)

        guard !name.isEmpty,
              letters[name] != nil || skippedNames.contains(name)
        else { break }

        if remaining.first == "[" {
            let number = remaining.dropFirst().prefix { $0 != "]" }

            remaining = remaining.dropFirst(number.count + 1)

            if remaining.first == "]" {
                remaining = remaining.dropFirst()
            }

            if let value = Double(number), value != 0 {
                current = value
            }
        } else {
            let run = remaining.prefix { $0 == "#" || $0 == "&" }

            remaining = remaining.dropFirst(run.count)

            let value = run.count { $0 == "#" } - run.count { $0 == "&" }

            if value != 0 {
                current = Double(value)
            }
        }

        if remaining.first == "+" || remaining.first == "-" {
            remaining = remaining.dropFirst()
        }

        remaining = remaining.drop { $0.isNumber }

        guard let letter = letters[name]
        else { continue }

        let accidental: Pitch.Accidental

        switch current {
        case -1:
            accidental = .flat

        case 0:
            accidental = .natural

        case 1:
            accidental = .sharp

        default:
            return nil
        }

        accidentals.append(PitchClass(letter: letter,
                                      accidental: accidental))
    }

    return KeySignature(accidentals: accidentals)
}

private func _parseKeyName(_ name: String) -> (keySignature: KeySignature, mode: String?)? {
    guard let first = name.first
    else { return KeySignature(fifths: 0).map { ($0, "major") } }

    guard let base = keyNameFifths[Character(first.uppercased())]
    else { return KeySignature(fifths: 0).map { ($0, "major") } }

    let isMajor = first.isUppercase
    var fifths = isMajor ? base : base - 3

    switch name.dropFirst().first {
    case "#":
        fifths += 7

    case "&":
        fifths -= 7

    default:
        break
    }

    return diatonicKeySignature(fifths: fifths).map { ($0, isMajor ? "major" : "minor") }
}
