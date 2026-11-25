// © 2026 John Gary Pusey (see LICENSE.md)

import Foundation
@testable import IvorExtern
import IvorModel
import IvorMXL
import IvorTiming
import IvorTuning
import Testing
import XestiNumbers
import XestiTools

//
// Keys through MusicXML: `<key>` in `<attributes>` in, key table entries
// out, and back.
//

struct MusicXMLKeyFunctionsTests {
}

// MARK: -

extension MusicXMLKeyFunctionsTests {
    @Test
    func export_atonalWritesModeNone() throws {
        #expect(try musicXMLExportedKeys(keyTable([(0, .atonal)])) == ["1@0 0 none"])
    }

    @Test
    func export_customKeyIsNonTraditional() throws {
        let keys = try musicXMLExportedKeys(keyTable([(0, customKey([.fSharp, .bFlat]))]))

        #expect(keys == ["1@0 Bb F#"])
    }

    @Test
    func export_emptyTableWritesNoKey() throws {
        #expect(try musicXMLExportedKeys(KeyTable()).isEmpty)
    }

    @Test
    func export_keyAtBarStartAndMidBar() throws {
        let table = try keyTable([(0, key(2, .major)),
                                  (1, key(-1, .minor)),         // bar 2's start
                                  (frac(3, 2), key(0))])        // halfway through bar 2, no mode

        #expect(try musicXMLExportedKeys(table) == ["1@0 2 major", "2@0 -1 minor", "2@8 0"])
    }

    @Test
    func import_doubleOrMicrotonalKeyIsDropped() throws {
        let work = try readMusicXMLMeteredMeasures([(nontraditionalKeyXML([("F", "1"), ("G", "2")]), musicXMLNote("C")),
                                                    (nontraditionalKeyXML([("B", "-0.5")]), musicXMLNote("C"))])

        #expect(keySummary(work.keyTable).isEmpty)
    }

    @Test
    func import_midMeasureKey() throws {
        let work = try readMusicXMLMeteredMeasures([(traditionalKeyXML(1),
                                                     musicXMLNote("C", duration: 2)
                                                        + "<attributes>\(traditionalKeyXML(-3))</attributes>"
                                                        + musicXMLNote("D", duration: 2))])

        #expect(keySummary(work.keyTable) == ["0 F#", "1/2 Bb Eb Ab"])
    }

    @Test
    func import_nonTraditionalKey() throws {
        let work = try readMusicXMLMeteredMeasures([(nontraditionalKeyXML([("B", "-1"), ("F", "1")]), musicXMLNote("C")),
                                                    (nontraditionalKeyXML([("C", "1"), ("F", "1")]), musicXMLNote("C"))])

        // The second is the usual two sharps, so it's diatonic, with no mode.
        #expect(keySummary(work.keyTable) == ["0 Bb F#", "1 F# C#"])
    }

    @Test
    func import_repeatedSectionReadsKeysAlongPlayOrder() throws {
        // | 2♯ C :| 1♭ C |, played as 2♯, 2♯ (restated: dropped), then 1♭ in the third bar.
        let work = try readMusicXMLMeteredMeasures([(traditionalKeyXML(2),
                                                     musicXMLNote("C") + #"<barline location="right"><repeat direction="backward"/></barline>"#),
                                                    (traditionalKeyXML(-1), musicXMLNote("C"))])

        #expect(keySummary(work.keyTable) == ["0 F# C#", "2 Bb"])
    }

    @Test
    func import_restatedKeyIsDropped() throws {
        let work = try readMusicXMLMeteredMeasures([(traditionalKeyXML(3, mode: "minor"), musicXMLNote("C")),
                                                    (traditionalKeyXML(3, mode: "minor"), musicXMLNote("C")),
                                                    (traditionalKeyXML(3, mode: "major"), musicXMLNote("C"))])

        #expect(keySummary(work.keyTable) == ["0 F# minor", "2 A major"])
    }

    @Test
    func import_secondStaffKeyIsIgnored() throws {
        let keys = #"<key number="2"><fifths>-2</fifths></key><key number="1"><fifths>1</fifths></key>"#
        let work = try readMusicXMLMeteredMeasures([(keys, musicXMLNote("C"))])

        #expect(keySummary(work.keyTable) == ["0 F#"])
    }

    @Test
    func import_traditionalKeyFoldsAndKeepsMode() throws {
        let work = try readMusicXMLMeteredMeasures([(traditionalKeyXML(9, mode: "Dorian"), musicXMLNote("C")),
                                                    (traditionalKeyXML(0, mode: "none"), musicXMLNote("C")),
                                                    (traditionalKeyXML(-2, mode: "bogus"), musicXMLNote("C")),
                                                    (traditionalKeyXML(1, mode: "ionian"), musicXMLNote("C")),
                                                    (traditionalKeyXML(0, mode: "aeolian"), musicXMLNote("C")),
                                                    (traditionalKeyXML(0), musicXMLNote("C"))])

        // 9♯ folds to 3♭; "none" is atonal; an unknown mode is no mode; ionian
        // and aeolian are major and minor.
        #expect(keySummary(work.keyTable) == ["0 F dorian", "1 Atonal", "2 Bb Eb", "3 G major", "4 A minor", "5 (no accidentals)"])
    }

    @Test
    func roundTrip_keysAndModes() throws {
        let table = try keyTable([(0, key(-3, .minor)),
                                  (1, customKey([.gSharp, .fSharp])),
                                  (frac(5, 2), key(4, .mixolydian)),
                                  (3, .atonal),
                                  (frac(7, 2), key(2))])
        let work = keyedStandardWork(table, pitches: Array(repeating: .c4, count: 16))
        let recovered = try roundTrip(work,
                                      exporter: MusicXML.Exporter(),
                                      importer: MusicXML.Importer(),
                                      fileFormat: .musicXML)

        // MusicXML loses nothing: modes, no mode, custom and atonal all survive.
        #expect(keySummary(recovered.keyTable) == ["0 C minor", "1 F# G#", "5/2 B mixolydian", "3 Atonal", "7/2 F# C#"])
    }

    @Test
    func roundTrip_noKeysStaysEmpty() throws {
        let work = keyedStandardWork(KeyTable(), pitches: [.c4, .d4])
        let recovered = try roundTrip(work,
                                      exporter: MusicXML.Exporter(),
                                      importer: MusicXML.Importer(),
                                      fileFormat: .musicXML)

        #expect(recovered.keyTable?.isEmpty == true)
    }

    @Test
    func roundTrip_noteAcrossAKeyChangeStaysWhole() throws {
        // A half note from 0, and a key change a quarter note into it: the
        // exporter splits the note there with a tie, which has to survive.
        var noteTable = NoteTable<BeatTime, Pitch>()

        noteTable.insert(attack: .zero, duration: .half, pitch: .c4)

        let table = try keyTable([(0, key(1, .major)), (frac(1, 4), key(-1, .major))])
        let work = Work(name: "Keyed",
                        content: .standardBeat([Part(name: "Piano", noteTable: noteTable)], TempoMap(), MeterTable(), table))
        let recovered = try roundTrip(work,
                                      exporter: MusicXML.Exporter(),
                                      importer: MusicXML.Importer(),
                                      fileFormat: .musicXML)
        let notes = try namedStandardPart(recovered, "Piano").noteTable

        #expect(keySummary(recovered.keyTable) == ["0 G major", "1/4 F major"])
        #expect(notes.count == 1)
        #expect(notes.first?.duration == .half)
    }
}
