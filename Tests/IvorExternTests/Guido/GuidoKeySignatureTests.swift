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
// Key signatures through Guido: `\key` tags in, key signature table entries
// out, and back.
//

struct GuidoKeySignatureTests {
}

// MARK: -

extension GuidoKeySignatureTests {

    // MARK: Import

    @Test(arguments: [(#"\key<"D">"#, "0 2# major"),
                      (#"\key<"b">"#, "0 2# minor"),
                      (#"\key<"B&">"#, "0 2b major"),
                      (#"\key<"e&">"#, "0 6b minor"),
                      (#"\key<"H">"#, "0 5# major"),
                      (#"\key<"f#">"#, "0 3# minor"),
                      (#"\key<"">"#, "0 no #/b major"),
                      (#"\key<-3>"#, "0 3b"),
                      (#"\key<9>"#, "0 3b"),                          // folded
                      (#"\key<"free=b&f#">"#, "0 Bb F#"),
                      (#"\key<"free=b& e a">"#, "0 3b"),              // running accidentals: diatonic, no mode
                      (#"\key<"free=f#+1 c#-2 g">"#, "0 3#"),         // octaves ignored; g takes the running sharp
                      (#"\key<"free=f[1] b[-1]">"#, "0 Bb F#"),
                      (#"\key<key="C", free="f# c#">"#, "0 2#")])     // the free parameter wins
    func import_keyTag(_ tag: String, _ summary: String) throws {
        let work = try readGuido("[ \(tag) c1/4 d e f ]")

        #expect(keySummary(work.keySignatureTable) == [summary])
    }

    @Test(arguments: [#"\key<"free=f## c#">"#,     // double
                      #"\key<"free=b[-1.5]">"#])    // microtonal
    func import_unrepresentableFreeKeyIsDropped(_ tag: String) throws {
        let work = try readGuido(#"[ \key<"G"> c1/4 d \#(tag) e f ]"#)

        #expect(keySummary(work.keySignatureTable) == ["0 1# major"])
    }

    @Test
    func roundTrip_noteAcrossAKeyChangeStaysWhole() throws {
        // A half note from 0, and a key change a quarter note into it: the
        // exporter splits the note there with a tie, and the `\key` between
        // the halves mustn't break it.
        var noteTable = NoteTable<BeatTime, Pitch>()

        noteTable.insert(attack: .zero, duration: .half, pitch: .c4)

        let table = try keyTable([(0, keySignature(1), "major"), (frac(1, 4), keySignature(-1), "major")])
        let work = Work(name: "Keyed",
                        content: .standardBeat([Part(name: "Piano", noteTable: noteTable)], TempoMap(), MeterTable(), table))
        let recovered = try roundTrip(work,
                                      exporter: Guido.Exporter(),
                                      importer: Guido.Importer(),
                                      fileFormat: .gmn)
        let notes = try namedStandardPart(recovered, "Piano").noteTable

        #expect(keySummary(recovered.keySignatureTable) == ["0 1# major", "1/4 1b major"])
        #expect(notes.count == 1)
        #expect(notes.first?.duration == .half)
    }

    // MARK: Export

    @Test
    func export_tags() throws {
        let table = try keyTable([(0, keySignature(-3), "minor"),
                                  (frac(1, 2), keySignature(2), "major"),
                                  (1, keySignature(4), "dorian"),
                                  (frac(3, 2), customKeySignature([.fSharp, .bFlat]), nil)])
        let score = try Guido.Exporter().convert(keyedStandardWork(table, pitches: Array(repeating: .c4, count: 8)))
        let keys = symbols(in: score).compactMap { symbol -> GMNTag.NumberOrName? in
            guard case let .tag(.key(key)) = symbol
            else { return nil }

            return key.key
        }

        #expect(keys == [.name("c"), .name("D"), .number(4), .name("free=b&f#")])
    }

    // MARK: Round trips

    @Test
    func roundTrip_keysAndModes() throws {
        let table = try keyTable([(0, keySignature(-6), "minor"),
                                  (frac(1, 4), keySignature(7), "major"),
                                  (frac(1, 2), customKeySignature([.gSharp, .fSharp]), nil),
                                  (frac(3, 4), keySignature(-2), "mixolydian")])
        let work = keyedStandardWork(table, pitches: Array(repeating: .c4, count: 4))
        let recovered = try roundTrip(work,
                                      exporter: Guido.Exporter(),
                                      importer: Guido.Importer(),
                                      fileFormat: .gmn)

        // Guido names only major and minor keys; other modes become numbers.
        #expect(keySummary(recovered.keySignatureTable) == ["0 6b minor", "1/4 7# major", "1/2 F# G#", "3/4 2b"])
    }

    @Test
    func roundTrip_noKeysStaysEmpty() throws {
        let work = keyedStandardWork(KeySignatureTable(), pitches: [.c4, .d4])
        let recovered = try roundTrip(work,
                                      exporter: Guido.Exporter(),
                                      importer: Guido.Importer(),
                                      fileFormat: .gmn)

        #expect(recovered.keySignatureTable?.isEmpty == true)
    }
}
