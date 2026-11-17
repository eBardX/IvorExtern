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
// Key signatures through MusicXML: `<key>` in `<attributes>` in, key
// signature table entries out, and back.
//

struct MusicXMLKeySignatureTests {
}

// MARK: -

extension MusicXMLKeySignatureTests {
    @Test
    func export_customKeyIsNonTraditional() throws {
        let keys = try exportedKeys(keyTable([(0, customKeySignature([.fSharp, .bFlat]), nil)]))

        #expect(keys == ["1@0 Bb F#"])
    }

    @Test
    func export_emptyTableWritesNoKey() throws {
        #expect(try exportedKeys(KeySignatureTable()).isEmpty)
    }

    @Test
    func export_keyAtBarStartAndMidBar() throws {
        let table = try keyTable([(0, keySignature(2), "major"),
                                  (1, keySignature(-1), "minor"),         // bar 2's start
                                  (frac(3, 2), keySignature(0), nil)])    // halfway through bar 2

        #expect(try exportedKeys(table) == ["1@0 2 major", "2@0 -1 minor", "2@8 0"])
    }

    @Test
    func import_doubleOrMicrotonalKeyIsDropped() throws {
        let work = try readMusicXMLMeteredMeasures([(nontraditional([("F", "1"), ("G", "2")]), musicXMLNote("C")),
                                                    (nontraditional([("B", "-0.5")]), musicXMLNote("C"))])

        #expect(keySummary(work.keySignatureTable).isEmpty)
    }

    @Test
    func import_nonTraditionalKey() throws {
        let work = try readMusicXMLMeteredMeasures([(nontraditional([("B", "-1"), ("F", "1")]), musicXMLNote("C")),
                                                    (nontraditional([("C", "1"), ("F", "1")]), musicXMLNote("C"))])

        // The second is the usual two sharps, so it's diatonic, with no mode.
        #expect(keySummary(work.keySignatureTable) == ["0 Bb F#", "1 2#"])
    }

    @Test
    func import_restatedKeyIsDropped() throws {
        let work = try readMusicXMLMeteredMeasures([(traditional(3, mode: "minor"), musicXMLNote("C")),
                                                    (traditional(3, mode: "minor"), musicXMLNote("C")),
                                                    (traditional(3, mode: "major"), musicXMLNote("C"))])

        #expect(keySummary(work.keySignatureTable) == ["0 3# minor", "2 3# major"])
    }

    @Test
    func import_secondStaffKeyIsIgnored() throws {
        let keys = #"<key number="2"><fifths>-2</fifths></key><key number="1"><fifths>1</fifths></key>"#
        let work = try readMusicXMLMeteredMeasures([(keys, musicXMLNote("C"))])

        #expect(keySummary(work.keySignatureTable) == ["0 1#"])
    }

    @Test
    func import_traditionalKeyFoldsAndKeepsMode() throws {
        let work = try readMusicXMLMeteredMeasures([(traditional(9, mode: "Dorian"), musicXMLNote("C")),
                                                    (traditional(0, mode: "none"), musicXMLNote("C")),
                                                    (traditional(-2, mode: "bogus"), musicXMLNote("C"))])

        #expect(keySummary(work.keySignatureTable) == ["0 3b dorian", "1 no #/b none", "2 2b"])
    }

    @Test
    func import_midMeasureKey() throws {
        let work = try readMusicXMLMeteredMeasures([(traditional(1),
                                                     musicXMLNote("C", duration: 2)
                                                        + "<attributes>\(traditional(-3))</attributes>"
                                                        + musicXMLNote("D", duration: 2))])

        #expect(keySummary(work.keySignatureTable) == ["0 1#", "1/2 3b"])
    }

    @Test
    func import_repeatedSectionReadsKeysAlongPlayOrder() throws {
        // | 2♯ C :| 1♭ C |, played as 2♯, 2♯ (restated: dropped), then 1♭ in the third bar.
        let work = try readMusicXMLMeteredMeasures([(traditional(2),
                                                     musicXMLNote("C") + #"<barline location="right"><repeat direction="backward"/></barline>"#),
                                                    (traditional(-1), musicXMLNote("C"))])

        #expect(keySummary(work.keySignatureTable) == ["0 2#", "2 1b"])
    }

    @Test
    func roundTrip_noteAcrossAKeyChangeStaysWhole() throws {
        // A half note from 0, and a key change a quarter note into it: the
        // exporter splits the note there with a tie, which has to survive.
        var noteTable = NoteTable<BeatTime, Pitch>()

        noteTable.insert(attack: .zero, duration: .half, pitch: .c4)

        let table = try keyTable([(0, keySignature(1), "major"), (frac(1, 4), keySignature(-1), "major")])
        let work = Work(name: "Keyed",
                        content: .standardBeat([Part(name: "Piano", noteTable: noteTable)], TempoMap(), MeterTable(), table))
        let recovered = try roundTrip(work,
                                      exporter: MusicXML.Exporter(),
                                      importer: MusicXML.Importer(),
                                      fileFormat: .musicXML)
        let notes = try namedStandardPart(recovered, "Piano").noteTable

        #expect(keySummary(recovered.keySignatureTable) == ["0 1# major", "1/4 1b major"])
        #expect(notes.count == 1)
        #expect(notes.first?.duration == .half)
    }

    @Test
    func roundTrip_keysAndModes() throws {
        let table = try keyTable([(0, keySignature(-3), "minor"),
                                  (1, customKeySignature([.gSharp, .fSharp]), nil),
                                  (frac(5, 2), keySignature(4), "mixolydian")])
        let work = keyedStandardWork(table, pitches: Array(repeating: .c4, count: 16))
        let recovered = try roundTrip(work,
                                      exporter: MusicXML.Exporter(),
                                      importer: MusicXML.Importer(),
                                      fileFormat: .musicXML)

        #expect(keySummary(recovered.keySignatureTable) == ["0 3b minor", "1 F# G#", "5/2 4# mixolydian"])
    }

    @Test
    func roundTrip_noKeysStaysEmpty() throws {
        let work = keyedStandardWork(KeySignatureTable(), pitches: [.c4, .d4])
        let recovered = try roundTrip(work,
                                      exporter: MusicXML.Exporter(),
                                      importer: MusicXML.Importer(),
                                      fileFormat: .musicXML)

        #expect(recovered.keySignatureTable?.isEmpty == true)
    }

    // Each `<key>` the first exported part writes, as
    // `"<measure>@<position> <fifths> <mode>"` for a traditional key or
    // `"<measure>@<position> <accidentals>"` for a non-traditional one, where
    // the position into the measure is in sixteenth notes.
    private func exportedKeys(_ table: KeySignatureTable) throws -> [String] {
        let score = try MusicXML.Exporter().convert(keyedStandardWork(table,
                                                                      pitches: Array(repeating: .c4, count: 8),
                                                                      meterTable: meterTable([(.zero, "4/4")])))
        var result: [String] = []

        for measure in score.parts[0].measures {
            var position = 0
            var divisions = 1

            for item in measure.items {
                switch item {
                case let .attributes(attributes):
                    if let value = attributes.divisions?.intValue {
                        divisions = value
                    }

                    for key in attributes.key {
                        result.append("\(measure.number)@\(position * 4 / divisions) \(describe(key))")
                    }

                case let .note(note):
                    if case let .regularNote(fullNote, duration, _) = note.content, !fullNote.isChord {
                        position += duration.intValue
                    }

                default:
                    continue
                }
            }
        }

        return result
    }

    private func describe(_ key: MXLKey) -> String {
        switch key.content {
        case let .nonTraditionalKey(groups):
            groups.map { "\($0.step)".uppercased() + ($0.alter < 0 ? "b" : "#") }.joined(separator: " ")

        case let .traditionalKey(traditional):
            ["\(traditional.fifths.intValue)", traditional.mode].compactMap(\.self).joined(separator: " ")
        }
    }

    private func nontraditional(_ pairs: [(step: String, alter: String)]) -> String {
        "<key>" + pairs.map { "<key-step>\($0.step)</key-step><key-alter>\($0.alter)</key-alter>" }.joined() + "</key>"
    }

    private func traditional(_ fifths: Int,
                             mode: String? = nil) -> String {
        "<key><fifths>\(fifths)</fifths>" + (mode.map { "<mode>\($0)</mode>" } ?? "") + "</key>"
    }
}
