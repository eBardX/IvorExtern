// © 2026 John Gary Pusey (see LICENSE.md)

// MARK: Internal Functions

// Returns the General MIDI 1/2 percussion key-map name for a 0–127 raw MIDI
// note number — the "Standard Kit" mapping every GM2 kit variation (Room,
// Power, Electronic, …) derives from and shares most of its voices with —
// or a synthesized "Percussion N" fallback for a note the key map leaves
// unassigned.
internal func generalMIDIPercussionName(note: Int) -> String {
    guard let name = generalMIDIPercussionNames[note]
    else { return "Percussion \(note)" }

    return name
}

// Returns the 0–127 raw MIDI note number for `name`, matched case-
// insensitively and whitespace-normalized against the key map, or by
// parsing the synthesized `"Percussion N"` fallback form produced by
// `generalMIDIPercussionName(note:)`. Returns `nil` on no match — callers
// must omit the percussion directive entirely on a miss rather than default
// to some arbitrary note.
internal func generalMIDIPercussionNote(name: String) -> Int? {
    let normalized = normalizeGeneralMIDIName(name)

    if let note = generalMIDIPercussionNotesByName[normalized] {
        return note
    }

    guard normalized.hasPrefix("percussion "),
          let note = Int(normalized.dropFirst("percussion ".count))
    else { return nil }

    return note
}

// MARK: Private Constants

// The GM1/GM2 "Standard Kit" percussion key map, indexed by raw 0–127 MIDI
// note number (channel 10's own convention) rather than program number —
// percussion sounds are selected by note, not by Program Change, so this
// deliberately doesn't share `GeneralMIDIInstruments.swift`'s table shape.
// Only notes 35–81 are assigned; every other note has no percussion sound
// defined.
private let generalMIDIPercussionNames: [Int: String] = [35: "Acoustic Bass Drum",
                                                         36: "Bass Drum 1",
                                                         37: "Side Stick",
                                                         38: "Acoustic Snare",
                                                         39: "Hand Clap",
                                                         40: "Electric Snare",
                                                         41: "Low Floor Tom",
                                                         42: "Closed Hi-Hat",
                                                         43: "High Floor Tom",
                                                         44: "Pedal Hi-Hat",
                                                         45: "Low Tom",
                                                         46: "Open Hi-Hat",
                                                         47: "Low-Mid Tom",
                                                         48: "Hi-Mid Tom",
                                                         49: "Crash Cymbal 1",
                                                         50: "High Tom",
                                                         51: "Ride Cymbal 1",
                                                         52: "Chinese Cymbal",
                                                         53: "Ride Bell",
                                                         54: "Tambourine",
                                                         55: "Splash Cymbal",
                                                         56: "Cowbell",
                                                         57: "Crash Cymbal 2",
                                                         58: "Vibraslap",
                                                         59: "Ride Cymbal 2",
                                                         60: "Hi Bongo",
                                                         61: "Low Bongo",
                                                         62: "Mute Hi Conga",
                                                         63: "Open Hi Conga",
                                                         64: "Low Conga",
                                                         65: "High Timbale",
                                                         66: "Low Timbale",
                                                         67: "High Agogo",
                                                         68: "Low Agogo",
                                                         69: "Cabasa",
                                                         70: "Maracas",
                                                         71: "Short Whistle",
                                                         72: "Long Whistle",
                                                         73: "Short Guiro",
                                                         74: "Long Guiro",
                                                         75: "Claves",
                                                         76: "Hi Wood Block",
                                                         77: "Low Wood Block",
                                                         78: "Mute Cuica",
                                                         79: "Open Cuica",
                                                         80: "Mute Triangle",
                                                         81: "Open Triangle"]

// A case-insensitive, whitespace-normalized reverse index of
// `generalMIDIPercussionNames`, built once.
private let generalMIDIPercussionNotesByName: [String: Int] = {
    var map: [String: Int] = [:]

    for (note, name) in generalMIDIPercussionNames {
        map[normalizeGeneralMIDIName(name)] = note
    }

    return map
}()
