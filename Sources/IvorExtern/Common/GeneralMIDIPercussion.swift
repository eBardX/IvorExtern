// © 2026 John Gary Pusey (see LICENSE.md)

private import IvorGeneralMIDI
private import IvorMIDI

// MARK: Internal Functions

// Returns the General MIDI 1 percussion key-map name for a 0–127 raw MIDI
// note number — the "Standard Kit" mapping every GM2 kit variation (Room,
// Power, Electronic, …) derives from and shares most of its voices with —
// or a synthesized "Percussion N" fallback for a note the key map leaves
// unassigned (only notes 35–81 have sounds).
internal func generalMIDIPercussionName(note: Int) -> String {
    guard let midiNote = UInt(exactly: note).flatMap({ MIDIData1Value(uintValue: $0) }),
          let sound = GM1PercussionSound(note: midiNote)
    else { return "Percussion \(note)" }

    return sound.name
}

// Returns the 0–127 raw MIDI note number for `name`, matched case-
// insensitively and whitespace-normalized against the key map, or by
// parsing the synthesized `"Percussion N"` fallback form produced by
// `generalMIDIPercussionName(note:)`. Returns `nil` on no match — callers
// must omit the percussion directive entirely on a miss rather than default
// to some arbitrary note.
internal func generalMIDIPercussionNote(name: String) -> Int? {
    if let sound = GM1PercussionSound(name: name) {
        return Int(sound.note.uintValue)
    }

    let normalized = name.lowercased()
        .split(whereSeparator: \.isWhitespace)
        .joined(separator: " ")

    guard normalized.hasPrefix("percussion "),
          let note = Int(normalized.dropFirst("percussion ".count))
    else { return nil }

    return note
}
