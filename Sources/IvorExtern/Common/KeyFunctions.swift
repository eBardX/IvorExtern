// © 2026 John Gary Pusey (see LICENSE.md)

internal import IvorModel
internal import IvorTiming
internal import IvorTuning

// MARK: Internal Functions

// The accidental `key` writes for `letter`: what a reader takes a bare note
// to be under that key. Natural for a letter the key doesn't alter, or when
// there's no key at all.
internal func accidental(for letter: Pitch.Letter,
                         in key: Key?) -> Pitch.Accidental {
    key?.accidentals.first { $0.letter == letter }?.accidental ?? .natural
}

// `fifths` sharps (or flats, when negative), folded by 12 fifths into −7…+7
// if it's beyond: 8 sharps is 4 flats. Every format but MIDI can write more
// than 7, though no one does.
internal func foldedFifths(_ fifths: Int) -> Int {
    var folded = fifths

    while folded > 7 {
        folded -= 12
    }

    while folded < -7 {
        folded += 12
    }

    return folded
}

// Builds an imported work's key table from the keys its source declares, in
// time order. Two at the same time: the later one wins. An entry that
// repeats the key in effect before it is dropped (MusicXML restates keys
// freely).
internal func makeKeyTable(_ changes: [(beatTime: BeatTime, key: Key)]) -> KeyTable {
    var latest: [(beatTime: BeatTime, key: Key)] = []

    for change in changes {
        if latest.last?.beatTime == change.beatTime {
            latest.removeLast()
        }

        latest.append(change)
    }

    var table = KeyTable()
    var previous: Key?

    for change in latest where change.key != previous {
        _ = try? table.insert(beatTime: change.beatTime,
                              key: change.key)

        previous = change.key
    }

    return table
}

// The tonic a format that always names one writes for a diatonic key: its
// own when it has a mode, otherwise its major tonic. `nil` for an atonal or
// custom key.
internal func writtenTonic(of key: Key) -> PitchClass? {
    guard case let .diatonic(diatonic) = key
    else { return nil }

    return diatonic.tonic ?? Key.Diatonic(fifths: diatonic.fifths,
                                          mode: .major)?.tonic
}
