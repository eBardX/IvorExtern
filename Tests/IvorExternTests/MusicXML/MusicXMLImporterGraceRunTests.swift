// © 2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import IvorModel
import IvorTiming
import IvorTuning
import Testing
import XestiNumbers

struct MusicXMLImporterGraceRunTests {
}

// MARK: -

extension MusicXMLImporterGraceRunTests {
    @Test
    func figure_after_isNeverTiedToMain() {
        var run = MusicXML.Importer.GraceRun()

        run.events = [graceRunEvent(["D4"])]
        run.isTiedForward = true

        #expect(run.figure(isAfter: true, mainDuration: dur(1, 4))?.isTiedToMainNote == false)
    }

    @Test
    func figure_after_stealsFromThePreviousIntoMain() throws {
        var run = MusicXML.Importer.GraceRun()

        run.events = [graceRunEvent(["D4"], stealTimeFollowing: 10, stealTimePrevious: 30)]

        let execution = try #require(run.figure(isAfter: true, mainDuration: dur(1, 4))?.events.first?.execution)

        #expect(try execution.fromMain == .share(proportion(3, 10)))
        #expect(try execution.fromPrevious == .share(proportion(1, 10)))
    }

    @Test
    func figure_before_stealsFromTheFollowingIntoMain() throws {
        var run = MusicXML.Importer.GraceRun()

        run.events = [graceRunEvent(["D4"], stealTimeFollowing: 25, stealTimePrevious: 50)]

        let execution = try #require(run.figure(isAfter: false, mainDuration: dur(1, 4))?.events.first?.execution)

        #expect(try execution.fromMain == .share(proportion(1, 4)))
        #expect(try execution.fromPrevious == .share(proportion(1, 2)))
    }

    @Test
    func figure_before_tiedForward_isTiedToMain() {
        var run = MusicXML.Importer.GraceRun()

        run.events = [graceRunEvent(["D4"])]
        run.isTiedForward = true

        #expect(run.figure(isAfter: false, mainDuration: dur(1, 4))?.isTiedToMainNote == true)
    }

    @Test
    func figure_chordPitches_areDedupedAndSorted() {
        var run = MusicXML.Importer.GraceRun()

        run.events = [graceRunEvent(["G4", "D4", "G4"])]

        #expect(run.figure(isAfter: false, mainDuration: dur(1, 4))?.events.first?.pitches == ["D4", "G4"])
    }

    @Test
    func figure_keepsTheSlashAndLength() throws {
        var run = MusicXML.Importer.GraceRun()
        let length = try #require(PositiveDuration(dur(1, 16)))

        run.events = [graceRunEvent(["D4"], length: length)]
        run.isSlashed = true

        let figure = run.figure(isAfter: false, mainDuration: dur(1, 4))

        #expect(figure?.isSlashed == true)
        #expect(figure?.events.first?.length == length)
    }

    @Test
    func figure_makeTime_isAShareOfMain() throws {
        var run = MusicXML.Importer.GraceRun()

        run.events = [graceRunEvent(["D4"], makeTime: dur(1, 16))]

        let execution = try #require(run.figure(isAfter: false, mainDuration: dur(1, 4))?.events.first?.execution)

        #expect(try execution.fromMain == .share(proportion(1, 4)))
        #expect(execution.fromPrevious == nil)
    }

    @Test
    func figure_makeTime_isCappedAtAllOfMain() throws {
        var run = MusicXML.Importer.GraceRun()

        run.events = [graceRunEvent(["D4"], makeTime: dur(1, 2))]

        let execution = try #require(run.figure(isAfter: false, mainDuration: dur(1, 4))?.events.first?.execution)

        #expect(try execution.fromMain == .share(proportion(1, 1)))
    }

    @Test
    func figure_noEvents_isNil() {
        #expect(MusicXML.Importer.GraceRun().figure(isAfter: false, mainDuration: dur(1, 4)) == nil)
    }

    @Test
    func figure_noTiming_hasNoExecution() {
        var run = MusicXML.Importer.GraceRun()

        run.events = [graceRunEvent(["D4"])]

        #expect(run.figure(isAfter: false, mainDuration: dur(1, 4))?.events.first?.execution == nil)
    }

    @Test
    func figure_stealTime_winsOverMakeTime() throws {
        var run = MusicXML.Importer.GraceRun()

        run.events = [graceRunEvent(["D4"], makeTime: dur(1, 16), stealTimeFollowing: 50)]

        let execution = try #require(run.figure(isAfter: false, mainDuration: dur(1, 4))?.events.first?.execution)

        #expect(try execution.fromMain == .share(proportion(1, 2)))
    }

    @Test
    func init_defaults() {
        let run = MusicXML.Importer.GraceRun()

        #expect(run.events.isEmpty)
        #expect(!run.followsPrevious)
        #expect(!run.isSlashed)
        #expect(!run.isTiedForward)
    }
}
