// © 2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import IvorModel
import IvorTiming
import IvorTuning
import Testing
import XestiNumbers
import XestiTools

//
// Keys through ABC: `K:` fields in, key table entries
// out, and back — with every note's accidental written relative to the key
// and to the accidentals earlier in its bar.
//

struct ABCKeyFunctionsTests {
}

// MARK: -

extension ABCKeyFunctionsTests {
    @Test
    func export_accidentalInAnotherOctaveIsRestated() throws {
        // ^F carries to f for ABC.Importer (by letter), but not for a reader
        // that carries it by octave, so f natural is written "=f", and F
        // natural "=F".
        let abc = try writeABC(keyedStandardWork(KeyTable(),
                                                 pitches: [.fSharp4, .f5, .f4, .c4],
                                                 meterTable: meterTable([(.zero, "4/4")])))

        #expect(abc.contains("^F=f=FC"))
    }

    @Test
    func export_accidentalsAgainstTheKeyWithinABar() throws {
        // In G: F♯ is bare, F♮ needs "=" once, then carries; the bar line
        // brings back F♯.
        let table = try keyTable([(0, key(1, .major))])
        let abc = try writeABC(keyedStandardWork(table,
                                                 pitches: [.fSharp4, .f4, .f4, .g4, .fSharp4],
                                                 meterTable: meterTable([(.zero, "4/4")])))

        #expect(abc.contains("K:G major"))
        #expect(abc.contains("F=FFG|F"))
    }

    @Test
    func export_atonalWritesKNone() throws {
        let table = try keyTable([(0, .atonal)])
        let abc = try writeABC(keyedStandardWork(table, pitches: [.fSharp4, .f4]))

        #expect(abc.contains("K:none"))
        #expect(abc.contains("^F=F"))
    }

    @Test
    func export_customKeyWritesExplicit() throws {
        let table = try keyTable([(0, customKey([.fSharp, .bFlat]))])
        let abc = try writeABC(keyedStandardWork(table,
                                                 pitches: [.bFlat4, .b4, .fSharp4, .f4],
                                                 meterTable: meterTable([(.zero, "4/4")])))

        #expect(abc.contains("K:C explicit _B ^F"))
        #expect(abc.contains("B=BF=F"))
    }

    @Test
    func export_emptyTableWritesKC() throws {
        let abc = try writeABC(keyedStandardWork(KeyTable(), pitches: [.bFlat4, .b4]))

        #expect(abc.contains("K:C major"))
        #expect(abc.contains("_B=B"))
    }

    @Test
    func export_keyChangeIsInlineAndResetsTheBar() throws {
        // D at 0, B♭ at 1/2 (mid-bar in 4/4): the inline field restarts the
        // bar's accidentals, as ABC.Importer reads it.
        let table = try keyTable([(0, key(2, .major)), (frac(1, 2), key(-2, .major))])
        let abc = try writeABC(keyedStandardWork(table,
                                                 pitches: [.fSharp4, .cSharp5, .bFlat4, .eFlat4],
                                                 meterTable: meterTable([(.zero, "4/4")])))

        #expect(abc.contains("K:D major"))
        #expect(abc.contains("Fc[K:Bb major]BE"))
    }

    @Test
    func export_modes() throws {
        let table = try keyTable([(0, key(2, .dorian)), (1, key(-3, .minor))])
        let abc = try writeABC(keyedStandardWork(table,
                                                 pitches: [.e4, .fSharp4, .g4, .a4, .c5, .d5, .eFlat5, .f5],
                                                 meterTable: meterTable([(.zero, "4/4")])))

        #expect(abc.contains("K:E dorian"))
        #expect(abc.contains("[K:C minor]"))
    }

    @Test
    func export_noModeWritesMajor() throws {
        let table = try keyTable([(0, key(1))])
        let abc = try writeABC(keyedStandardWork(table, pitches: [.fSharp4]))

        #expect(abc.contains("K:G major"))
    }

    @Test
    func import_doubleAccidentalKeyIsDropped() throws {
        let work = try readABC("X:1\nT:T\nL:1/4\nK:C\nC D|[K:C exp ^^f] E F|\n")

        #expect(keySummary(work.keyTable) == ["0 C major"])
    }

    @Test
    func import_inlineKeyChangesAlongPlayOrder() throws {
        let work = try readABC("""
            X:1
            T:T
            L:1/4
            K:C
            |:C D [K:G] E F:|[K:Bb] G A B c|
            """)

        // The repeat restates G at 3/2: dropped.
        #expect(keySummary(work.keyTable) == ["0 C major", "1/2 G major", "2 Bb major"])
    }

    @Test(arguments: [("K:D", "0 D major"),
                      ("K:Bm", "0 B minor"),
                      ("K:Edor", "0 E dorian"),
                      ("K:F lyd", "0 F lydian"),
                      ("K:Ab aeolian", "0 Ab minor"),       // aeolian is minor
                      ("K:G ionian", "0 G major"),          // ionian is major
                      ("K:none", "0 Atonal"),
                      ("K:D ^g", "0 F# C# G#"),             // extra accidentals: no mode
                      ("K:D =c", "0 F#"),
                      ("K:D ^d", "0 F# C# D#"),             // custom
                      ("K:C exp _b ^f", "0 Bb F#"),
                      ("K:C exp ^f", "0 F#")])              // diatonic set: no mode
    func import_keyField(_ field: String, _ summary: String) throws {
        let work = try readABC("X:1\nT:T\nL:1/4\n\(field)\nC D E F|\n")

        #expect(keySummary(work.keyTable) == [summary])
    }

    @Test
    func roundTrip_atonalAndNoMode() throws {
        // Atonal survives; no mode comes back as major, since ABC always
        // names a tonic.
        let table = try keyTable([(0, .atonal), (1, key(2))])
        let work = try keyedStandardWork(table,
                                         pitches: [.c4, .fSharp4, .f4, .c4, .d4, .fSharp4, .cSharp5, .d5],
                                         meterTable: meterTable([(.zero, "4/4")]))
        let recovered = try readABC(writeABC(work))

        #expect(keySummary(recovered.keyTable) == ["0 Atonal", "1 D major"])
    }

    @Test
    func roundTrip_keysModesAndPitches() throws {
        let table = try keyTable([(0, key(-3, .minor)),
                                  (1, customKey([.gSharp, .fSharp])),
                                  (2, key(4, .mixolydian))])
        let pitches: [Pitch] = [.c4,
                                .eFlat4,
                                .e4,
                                .eFlat4,
                                .bFlat4,
                                .b4,
                                .b5,
                                .bFlat5,
                                .fSharp4,
                                .f4,
                                .gSharp4,
                                .g4,
                                .f5,
                                .fSharp5,
                                .c5,
                                .cSharp5,
                                .dSharp4,
                                .d4,
                                .d4,
                                .dSharp4,
                                .gSharp4,
                                .aSharp4,
                                .a4,
                                .cSharp4]
        let work = try keyedStandardWork(table,
                                         pitches: pitches,
                                         meterTable: meterTable([(.zero, "4/4")]))
        let recovered = try readABC(writeABC(work))

        #expect(keySummary(recovered.keyTable) == ["0 C minor", "1 F# G#", "2 B mixolydian"])

        // ABC.Importer respells every pitch with sharps, so compare what sounds.
        #expect(try namedStandardPart(recovered, "Piano").noteTable.map { pitchSemitones($0.startPitch) } == pitches.map(pitchSemitones))
    }

    @Test
    func roundTrip_noKeysGivesKC() throws {
        let work = keyedStandardWork(KeyTable(), pitches: [.c4, .fSharp4])
        let recovered = try readABC(writeABC(work))

        #expect(keySummary(recovered.keyTable) == ["0 C major"])
    }

    @Test
    func roundTrip_normalizesModeNames() throws {
        let recovered = try readABC(writeABC(readABC("X:1\nT:T\nL:1/4\nK:Aaeo\nA B c d|\n")))

        #expect(keySummary(recovered.keyTable) == ["0 A minor"])
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
                                      exporter: ABC.Exporter(),
                                      importer: ABC.Importer(),
                                      fileFormat: .abc)
        let notes = try namedStandardPart(recovered, "Piano").noteTable

        #expect(keySummary(recovered.keyTable) == ["0 G major", "1/4 F major"])
        #expect(notes.count == 1)
        #expect(notes.first?.duration == .half)
    }
}
