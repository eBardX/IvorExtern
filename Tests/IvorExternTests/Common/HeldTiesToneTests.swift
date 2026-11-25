// © 2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import IvorModel
import IvorTiming
import IvorTuning
import Testing

struct HeldTiesToneTests {
}

// MARK: -

extension HeldTiesToneTests {
    @Test
    func init_defaultsToNoOrnamentation() {
        let tone = HeldTies.Tone(attack: beat(0),
                                 duration: dur(1),
                                 extras: nil,
                                 isTied: true,
                                 pitch: "C4")

        #expect(tone.attack == beat(0))
        #expect(tone.duration == dur(1))
        #expect(tone.extras == nil)
        #expect(tone.isTied)
        #expect(tone.ornamentation == nil)
        #expect(tone.pitch == "C4")
    }

    @Test
    func insert_addsTheNote() {
        var noteTable = NoteTable<BeatTime, Pitch>()
        let tone = HeldTies.Tone(attack: beat(1, 2),
                                 duration: dur(1, 4),
                                 extras: channelExtras(2),
                                 isTied: false,
                                 pitch: "E4")

        tone.insert(into: &noteTable)

        let note = noteTable.first

        #expect(noteTable.count == 1)
        #expect(note?.attack == beat(1, 2))
        #expect(note?.duration == dur(1, 4))
        #expect(note?.startPitch == "E4")
        #expect(note?.extras == channelExtras(2))
    }

    @Test
    func insert_keepsOrnamentation() throws {
        var noteTable = NoteTable<BeatTime, Pitch>()
        let mordent = try #require(BeatNotes.Ornament(sign: .mordent, partner: .step(.below, written: nil)))
        let tone = HeldTies.Tone(attack: beat(0),
                                 duration: dur(1),
                                 extras: nil,
                                 isTied: false,
                                 ornamentation: .init(ornament: mordent),
                                 pitch: "C4")

        tone.insert(into: &noteTable)

        #expect(noteTable.first?.ornamentation?.ornament == mordent)
    }
}
