// © 2026 John Gary Pusey (see LICENSE.md)

// MARK: Internal Functions

// Returns the General MIDI 1 instrument name for a 0–127 program number, or
// a synthesized "Program N" fallback for a value outside that range (a
// hand-parsed directive can carry one).
internal func generalMIDIInstrumentName(program: Int) -> String {
    guard generalMIDIInstrumentNames.indices.contains(program)
    else { return "Program \(program)" }

    return generalMIDIInstrumentNames[program]
}

// Returns the 0–127 General MIDI 1 program number for `name`, matched
// case-insensitively and whitespace-normalized against the table, or by
// parsing the synthesized `"Program N"` fallback form produced by
// `generalMIDIInstrumentName(program:)`. Returns `nil` on no match — callers
// must omit the instrument directive entirely on a miss rather than default
// to program 0, which would mislabel every unrecognized instrument as
// Acoustic Grand Piano.
internal func generalMIDIProgramNumber(name: String) -> Int? {
    let normalized = _normalizeGeneralMIDIInstrumentName(name)

    if let program = generalMIDIProgramNumbersByName[normalized] {
        return program
    }

    guard normalized.hasPrefix("program "),
          let program = Int(normalized.dropFirst("program ".count))
    else { return nil }

    return program
}

// MARK: Private Constants

// The 128 General MIDI 1 instrument names, in patch order. Every importer
// that only has a numeric MIDI program number to work with (MIDI itself,
// Guido's `\instr` `MIDI` parameter, and ABC's `%%MIDI program` directive)
// renders it through this table rather than surfacing the bare number.
//
// Indexed by the raw 0–127 MIDI program-change value — the same convention
// `MIDIData1Value` and Guido's `\instr` `MIDI` parameter both use (proven for
// Guido by `GMNInstrumentTests.promotes()`, which pairs `MIDI=71` with
// "Clarinet" — GM patch 72 in the 1-based numbering most GM tables print,
// i.e. 0-based index 71). MusicXML's `<midi-program>` is the one format that
// numbers 1–128 instead (`MXLMidi128`), so its call site subtracts 1 before
// indexing here.
private let generalMIDIInstrumentNames: [String] = ["Acoustic Grand Piano",
                                                    "Bright Acoustic Piano",
                                                    "Electric Grand Piano",
                                                    "Honky-tonk Piano",
                                                    "Electric Piano 1",
                                                    "Electric Piano 2",
                                                    "Harpsichord",
                                                    "Clavinet",
                                                    "Celesta",
                                                    "Glockenspiel",
                                                    "Music Box",
                                                    "Vibraphone",
                                                    "Marimba",
                                                    "Xylophone",
                                                    "Tubular Bells",
                                                    "Dulcimer",
                                                    "Drawbar Organ",
                                                    "Percussive Organ",
                                                    "Rock Organ",
                                                    "Church Organ",
                                                    "Reed Organ",
                                                    "Accordion",
                                                    "Harmonica",
                                                    "Tango Accordion",
                                                    "Acoustic Guitar (nylon)",
                                                    "Acoustic Guitar (steel)",
                                                    "Electric Guitar (jazz)",
                                                    "Electric Guitar (clean)",
                                                    "Electric Guitar (muted)",
                                                    "Overdriven Guitar",
                                                    "Distortion Guitar",
                                                    "Guitar Harmonics",
                                                    "Acoustic Bass",
                                                    "Electric Bass (finger)",
                                                    "Electric Bass (pick)",
                                                    "Fretless Bass",
                                                    "Slap Bass 1",
                                                    "Slap Bass 2",
                                                    "Synth Bass 1",
                                                    "Synth Bass 2",
                                                    "Violin",
                                                    "Viola",
                                                    "Cello",
                                                    "Contrabass",
                                                    "Tremolo Strings",
                                                    "Pizzicato Strings",
                                                    "Orchestral Harp",
                                                    "Timpani",
                                                    "String Ensemble 1",
                                                    "String Ensemble 2",
                                                    "Synth Strings 1",
                                                    "Synth Strings 2",
                                                    "Choir Aahs",
                                                    "Voice Oohs",
                                                    "Synth Voice",
                                                    "Orchestra Hit",
                                                    "Trumpet",
                                                    "Trombone",
                                                    "Tuba",
                                                    "Muted Trumpet",
                                                    "French Horn",
                                                    "Brass Section",
                                                    "Synth Brass 1",
                                                    "Synth Brass 2",
                                                    "Soprano Sax",
                                                    "Alto Sax",
                                                    "Tenor Sax",
                                                    "Baritone Sax",
                                                    "Oboe",
                                                    "English Horn",
                                                    "Bassoon",
                                                    "Clarinet",
                                                    "Piccolo",
                                                    "Flute",
                                                    "Recorder",
                                                    "Pan Flute",
                                                    "Blown Bottle",
                                                    "Shakuhachi",
                                                    "Whistle",
                                                    "Ocarina",
                                                    "Lead 1 (square)",
                                                    "Lead 2 (sawtooth)",
                                                    "Lead 3 (calliope)",
                                                    "Lead 4 (chiff)",
                                                    "Lead 5 (charang)",
                                                    "Lead 6 (voice)",
                                                    "Lead 7 (fifths)",
                                                    "Lead 8 (bass + lead)",
                                                    "Pad 1 (new age)",
                                                    "Pad 2 (warm)",
                                                    "Pad 3 (polysynth)",
                                                    "Pad 4 (choir)",
                                                    "Pad 5 (bowed)",
                                                    "Pad 6 (metallic)",
                                                    "Pad 7 (halo)",
                                                    "Pad 8 (sweep)",
                                                    "FX 1 (rain)",
                                                    "FX 2 (soundtrack)",
                                                    "FX 3 (crystal)",
                                                    "FX 4 (atmosphere)",
                                                    "FX 5 (brightness)",
                                                    "FX 6 (goblins)",
                                                    "FX 7 (echoes)",
                                                    "FX 8 (sci-fi)",
                                                    "Sitar",
                                                    "Banjo",
                                                    "Shamisen",
                                                    "Koto",
                                                    "Kalimba",
                                                    "Bag pipe",
                                                    "Fiddle",
                                                    "Shanai",
                                                    "Tinkle Bell",
                                                    "Agogo",
                                                    "Steel Drums",
                                                    "Woodblock",
                                                    "Taiko Drum",
                                                    "Melodic Tom",
                                                    "Synth Drum",
                                                    "Reverse Cymbal",
                                                    "Guitar Fret Noise",
                                                    "Breath Noise",
                                                    "Seashore",
                                                    "Bird Tweet",
                                                    "Telephone Ring",
                                                    "Helicopter",
                                                    "Applause",
                                                    "Gunshot"]

// A case-insensitive, whitespace-normalized reverse index of
// `generalMIDIInstrumentNames`, built once. Keys are normalized with
// `_normalizeGeneralMIDIInstrumentName(_:)` so lookups match regardless of
// case or incidental whitespace differences.
private let generalMIDIProgramNumbersByName: [String: Int] = {
    var map: [String: Int] = [:]

    for (program, name) in generalMIDIInstrumentNames.enumerated() {
        map[_normalizeGeneralMIDIInstrumentName(name)] = program
    }

    return map
}()

// MARK: Private Functions

// Lowercases and collapses runs of whitespace into single spaces, trimming
// leading/trailing whitespace, so lookups are insensitive to both.
private func _normalizeGeneralMIDIInstrumentName(_ name: String) -> String {
    name.lowercased()
        .split(separator: " ", omittingEmptySubsequences: true)
        .joined(separator: " ")
}
