// © 2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import IvorGMN
import IvorModel
import IvorTiming
import IvorTuning
import Testing
import XestiNumbers
import XestiTools

//
// Keys through Guido: `\key` tags in, key table entries
// out, and back.
//

struct GuidoKeyFunctionsTests {
}

// MARK: -

extension GuidoKeyFunctionsTests {
    @Test
    func export_tags() throws {
        let table = try keyTable([(0, key(-3, .minor)),
                                  (frac(1, 2), key(2, .major)),
                                  (1, key(4, .dorian)),
                                  (frac(5, 4), key(-1)),
                                  (frac(3, 2), customKey([.fSharp, .bFlat])),
                                  (frac(7, 4), .atonal)])
        let score = try Guido.Exporter().convert(keyedStandardWork(table, pitches: Array(repeating: .c4, count: 8)))
        let keys = symbols(in: score).compactMap { symbol -> GMNTag.NumberOrName? in
            guard case let .tag(.key(key)) = symbol
            else { return nil }

            return key.key
        }

        #expect(keys == [.name("c"), .name("D"), .number(4), .number(-1), .name("free=b&f#"), .number(0)])
    }

    @Test(arguments: [(#"\key<"D">"#, "0 D major"),
                      (#"\key<"b">"#, "0 B minor"),
                      (#"\key<"B&">"#, "0 Bb major"),
                      (#"\key<"e&">"#, "0 Eb minor"),
                      (#"\key<"H">"#, "0 B major"),
                      (#"\key<"f#">"#, "0 F# minor"),
                      (#"\key<"">"#, "0 C major"),
                      (#"\key<-3>"#, "0 Bb Eb Ab"),                   // a number: no mode
                      (#"\key<9>"#, "0 Bb Eb Ab"),                    // folded
                      (#"\key<"free=b&f#">"#, "0 Bb F#"),
                      (#"\key<"free=b& e a">"#, "0 Bb Eb Ab"),        // running accidentals: diatonic, no mode
                      (#"\key<"free=f#+1 c#-2 g">"#, "0 F# C# G#"),   // octaves ignored; g takes the running sharp
                      (#"\key<"free=f[1] b[-1]">"#, "0 Bb F#"),
                      (#"\key<key="C", free="f# c#">"#, "0 F# C#")])  // the free parameter wins
    func import_keyTag(_ tag: String, _ summary: String) throws {
        let work = try readGuido("[ \(tag) c1/4 d e f ]")

        #expect(keySummary(work.keyTable) == [summary])
    }

    @Test(arguments: [#"\key<"free=f## c#">"#,     // double
                      #"\key<"free=b[-1.5]">"#])    // microtonal
    func import_unrepresentableFreeKeyIsDropped(_ tag: String) throws {
        let work = try readGuido(#"[ \key<"G"> c1/4 d \#(tag) e f ]"#)

        #expect(keySummary(work.keyTable) == ["0 G major"])
    }

    @Test
    func roundTrip_keysAndModes() throws {
        let table = try keyTable([(0, key(-6, .minor)),
                                  (frac(1, 4), key(7, .major)),
                                  (frac(1, 2), customKey([.gSharp, .fSharp])),
                                  (frac(3, 4), key(-2, .mixolydian)),
                                  (1, .atonal)])
        let work = keyedStandardWork(table, pitches: Array(repeating: .c4, count: 6))
        let recovered = try roundTrip(work,
                                      exporter: Guido.Exporter(),
                                      importer: Guido.Importer(),
                                      fileFormat: .gmn)

        // Guido names only major and minor keys; other modes become numbers,
        // with no mode, and atonal becomes no sharps or flats.
        #expect(keySummary(recovered.keyTable) == ["0 Eb minor", "1/4 C# major", "1/2 F# G#", "3/4 Bb Eb", "1 (no accidentals)"])
    }

    @Test
    func roundTrip_noKeysStaysEmpty() throws {
        let work = keyedStandardWork(KeyTable(), pitches: [.c4, .d4])
        let recovered = try roundTrip(work,
                                      exporter: Guido.Exporter(),
                                      importer: Guido.Importer(),
                                      fileFormat: .gmn)

        #expect(recovered.keyTable?.isEmpty == true)
    }

    @Test
    func roundTrip_noteAcrossAKeyChangeStaysWhole() throws {
        // A half note from 0, and a key change a quarter note into it: the
        // exporter splits the note there with a tie, and the `\key` between
        // the halves mustn't break it.
        var noteTable = NoteTable<BeatTime, Pitch>()

        noteTable.insert(attack: .zero, duration: .half, pitch: .c4)

        let table = try keyTable([(0, key(1, .major)), (frac(1, 4), key(-1, .major))])
        let work = Work(name: "Keyed",
                        content: .standardBeat([Part(name: "Piano", noteTable: noteTable)], TempoMap(), MeterTable(), table))
        let recovered = try roundTrip(work,
                                      exporter: Guido.Exporter(),
                                      importer: Guido.Importer(),
                                      fileFormat: .gmn)
        let notes = try namedStandardPart(recovered, "Piano").noteTable

        #expect(keySummary(recovered.keyTable) == ["0 G major", "1/4 F major"])
        #expect(notes.count == 1)
        #expect(notes.first?.duration == .half)
    }
}
