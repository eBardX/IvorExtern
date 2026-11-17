// © 2026 John Gary Pusey (see LICENSE.md)

internal import IvorModel
internal import IvorTiming
internal import IvorTuning
internal import XestiTools

// MARK: Internal Functions

// The diatonic key signature with `fifths` sharps (or flats, when negative),
// folded by 12 fifths into −7…+7 if it's beyond: 8 sharps is 4 flats. Every
// format but MIDI can write more than 7, though no one does.
internal func diatonicKeySignature(fifths: Int) -> KeySignature? {
    var folded = fifths

    while folded > 7 {
        folded -= 12
    }

    while folded < -7 {
        folded += 12
    }

    return KeySignature(fifths: folded)
}

// Whether `mode` names a minor key (minor or aeolian), as MIDI's `mi` and
// Guido's lowercase key names record it.
internal func isMinorMode(_ mode: String?) -> Bool {
    mode == "minor" || mode == "aeolian"
}

// The `keySignatureMode` extra for `mode`, a mode name as the formats share
// it, or `nil` for none.
internal func keySignatureModeExtras(_ mode: String?) -> Extras? {
    guard let mode
    else { return nil }

    return Extras(elements: [Extra(name: Extra.keySignatureMode.name,
                                   values: [.string(mode)])])
}

// The mode name `name` stands for, if it's one the formats share (in any
// case): major, minor, the seven church modes, or none.
internal func keySignatureModeName(_ name: String) -> String? {
    let lowered = name.lowercased()

    return modeIndices.keys.contains(lowered) || lowered == "none" ? lowered : nil
}

// Builds an imported work's key signature table from the key signatures its
// source declares, in time order, each with the source's mode name, if any.
// Two at the same time: the later one wins. An entry that repeats the key
// signature and mode in effect before it is dropped (MusicXML restates keys
// freely). A custom signature never keeps a mode, since no format can write
// one back for it.
internal func makeKeySignatureTable(_ changes: [(beatTime: BeatTime, keySignature: KeySignature, mode: String?)]) -> KeySignatureTable {
    var latest: [(beatTime: BeatTime, keySignature: KeySignature, mode: String?)] = []

    for change in changes {
        let mode = change.keySignature.isDiatonic ? change.mode : nil

        if latest.last?.beatTime == change.beatTime {
            latest.removeLast()
        }

        latest.append((change.beatTime, change.keySignature, mode))
    }

    var table = KeySignatureTable()
    var previous: (keySignature: KeySignature, mode: String?)?

    for change in latest {
        if let previous,
           previous.keySignature == change.keySignature,
           previous.mode == change.mode {
            continue
        }

        _ = try? table.insert(beatTime: change.beatTime,
                              keySignature: change.keySignature,
                              extras: keySignatureModeExtras(change.mode))

        previous = (change.keySignature, change.mode)
    }

    return table
}

// The tonic of a diatonic key signature in `mode`, or its major tonic when
// there's no mode (or "none", or one not recognized); `nil` for a custom
// signature. A mode is an index into the signature's diatonic collection:
// for 2♯, major is D, minor B, dorian E.
internal func tonic(of keySignature: KeySignature,
                    mode: String?) -> PitchClass? {
    guard let collection = keySignature.diatonicCollection
    else { return nil }

    return collection[mode.flatMap { modeIndices[$0] } ?? 1]
}

// MARK: Private Constants

// The index of each mode's tonic in a diatonic collection, which runs in
// fifths from one below the major tonic.
private let modeIndices: [String: Int] = ["aeolian": 4,
                                          "dorian": 3,
                                          "ionian": 1,
                                          "locrian": 6,
                                          "lydian": 0,
                                          "major": 1,
                                          "minor": 4,
                                          "mixolydian": 2,
                                          "phrygian": 5]
