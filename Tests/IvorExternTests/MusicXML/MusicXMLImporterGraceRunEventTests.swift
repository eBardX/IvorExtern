// © 2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import IvorModel
import IvorTiming
import IvorTuning
import Testing

struct MusicXMLImporterGraceRunEventTests {
}

// MARK: -

extension MusicXMLImporterGraceRunEventTests {
    @Test
    func init_storesValues() throws {
        let length = try #require(PositiveDuration(dur(1, 8)))
        let event = MusicXML.Importer.GraceRun.Event(length: length,
                                                     makeTime: dur(1, 16),
                                                     pitches: ["D4"],
                                                     stealTimeFollowing: 25,
                                                     stealTimePrevious: nil)

        #expect(event.length == length)
        #expect(event.makeTime == dur(1, 16))
        #expect(event.pitches == ["D4"])
        #expect(event.stealTimeFollowing == 25)
        #expect(event.stealTimePrevious == nil)
    }

    @Test
    func pitches_chordGraceNotesAppend() {
        var event = MusicXML.Importer.GraceRun.Event(length: nil,
                                                     makeTime: nil,
                                                     pitches: ["D4"],
                                                     stealTimeFollowing: nil,
                                                     stealTimePrevious: nil)

        event.pitches.append("F4")

        #expect(event.pitches == ["D4", "F4"])
    }
}
