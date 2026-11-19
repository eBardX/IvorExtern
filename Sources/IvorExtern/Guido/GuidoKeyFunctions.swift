// © 2026 John Gary Pusey (see LICENSE.md)

internal import IvorGMN
internal import IvorTuning

// MARK: Internal Functions

// The `\key` tag for a key. A diatonic key in major or minor is written as
// its key name, as guidolib reads one: the tonic's letter, uppercase for
// major and lowercase for minor, then `#` or `&` for a sharp or flat tonic
// (`\key<"D">`, `\key<"e&">`). Any other diatonic key, in another mode or
// with none, is written as its number of fifths (`\key<2>`), and an atonal
// key as `\key<0>`, since Guido can't say more. A custom key is written as a
// free key, every note with its own accidental, in canonical order
// (`\key<"free=b&f#">`), so its meaning doesn't depend on guidolib's running
// accidentals.
internal func convertToGMNKey(_ key: Key) -> GMNKey {
    switch key {
    case .atonal:
        return GMNKey(key: .number(0))

    case let .custom(signature):
        let spec = signature.accidentals.map { pitchClass in
            "\(pitchClass.letter)".lowercased() + (pitchClass.accidental == .flat ? "&" : "#")
        }

        return GMNKey(key: .name("free=" + spec.joined()))

    case let .diatonic(diatonic):
        guard let mode = diatonic.mode,
              mode == .major || mode == .minor,
              let tonic = diatonic.tonic
        else { return GMNKey(key: .number(diatonic.fifths)) }

        let letter = "\(tonic.letter)"
        let name = (mode == .minor ? letter.lowercased() : letter.uppercased()) + _guidoAccidental(tonic.accidental)

        return GMNKey(key: .name(name))
    }
}

// A `\key` tag's key, read as guidolib's `ARKey` reads it. A number is a
// diatonic key with that many sharps (or flats), folded into −7…+7, and no
// mode. A name is a major or minor key: its first letter the tonic (`H` or
// `B` for B), uppercase for major and lowercase for minor, and a second
// character of `#` or `&` raising or lowering it. An empty name is C major,
// and an unknown letter C major too, as guidolib takes them. A name starting
// `free=`, or a `free` parameter, is a free key (see `_parseFreeKey(_:)`),
// whose accidentals give the key with no mode. `nil` for a free key that
// needs a double or microtonal alteration.
internal func convertToKey(_ key: GMNKey) -> Key? {
    if let free = key.free {
        return _parseFreeKey(free)
    }

    switch key.key {
    case let .name(name):
        if name.hasPrefix(freePrefix) {
            return _parseFreeKey(String(name.dropFirst(freePrefix.count)))
        }

        return _parseKeyName(name)

    case let .number(fifths):
        return Key.diatonic(fifths: foldedFifths(fifths),
                            mode: nil)
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
private func _parseFreeKey(_ spec: String) -> Key? {
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

    return Key(accidentals: accidentals)
}

private func _parseKeyName(_ name: String) -> Key? {
    guard let first = name.first,
          let base = keyNameFifths[Character(first.uppercased())]
    else { return Key.diatonic(fifths: 0, mode: .major) }

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

    return Key.diatonic(fifths: foldedFifths(fifths),
                        mode: isMajor ? .major : .minor)
}
