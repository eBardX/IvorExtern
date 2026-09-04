// © 2026 John Gary Pusey (see LICENSE.md)

import Foundation
import IvorABC
@testable import IvorExtern
import IvorModel
import IvorTiming
import IvorTuning
import Testing
import XestiNumbers

struct ABCImporterWalkerTests {
    private let walker = ABC.Importer.Walker()
}

// MARK: -

extension ABCImporterWalkerTests {
    @Test
    func walk_brokenRhythm_rescalesFlankingNotes() throws {
        let abc = """
            X:1
            L:1/4
            K:C
            C>D|
            """
        let (tunebook, _) = try ABC.BaseParser().parse(Data(abc.utf8))
        let tune = try #require(tunebook.tunes.first)

        let results = try walker.walk(tune, fileHeader: tunebook.fileHeader)

        var durations: [BeatDuration] = []

        results[0].context.noteTable.forEach { _, _, duration, _, _, _ in durations.append(duration) }

        #expect(durations == [BeatDuration(Number(numerator: 3, denominator: 2)),
                              BeatDuration(Number(numerator: 1, denominator: 2))])
    }

    @Test
    func walk_dynamicsDecoration_recordsStepDynamicEvent() throws {
        let abc = """
            X:1
            L:1/4
            K:C
            !mf!C D|
            """
        let (tunebook, _) = try ABC.BaseParser().parse(Data(abc.utf8))
        let tune = try #require(tunebook.tunes.first)

        let results = try walker.walk(tune, fileHeader: tunebook.fileHeader)
        let events = results[0].context.dynamicEvents

        #expect(events.count == 1)
        #expect(events.first?.beatTime == .zero)
        #expect(events.first?.dynamic == .mf)
        #expect(events.first?.kind == .step)
    }

    @Test
    func walk_hairpin_recordsRampBoundaryEvents() throws {
        let abc = """
            X:1
            L:1/4
            K:C
            !<(!C D!<)!E|
            """
        let (tunebook, _) = try ABC.BaseParser().parse(Data(abc.utf8))
        let tune = try #require(tunebook.tunes.first)

        let results = try walker.walk(tune, fileHeader: tunebook.fileHeader)
        let events = results[0].context.dynamicEvents

        #expect(events.count == 2)
        #expect(events.allSatisfy { $0.kind == .rampBoundary })
        #expect(events.first?.beatTime == .zero)
        #expect(events.first?.dynamic == .mp)
        #expect(events.last?.beatTime == BeatTime(2))
        #expect(events.last?.dynamic == .mf)
    }

    @Test
    func walk_macroField_expandsMacroInBody() throws {
        let abc = """
            X:1
            L:1/4
            K:C
            m:C = D
            C E|
            """
        let (tunebook, _) = try ABC.BaseParser().parse(Data(abc.utf8))
        let tune = try #require(tunebook.tunes.first)

        let results = try walker.walk(tune, fileHeader: tunebook.fileHeader)

        var pitches: [Pitch] = []

        results[0].context.noteTable.forEach { _, _, _, startPitch, _, _ in pitches.append(startPitch) }

        #expect(pitches == ["D4", "E4"])
    }

    @Test
    func walk_multiVoice_routesEachVoiceSeparately() throws {
        let abc = """
            X:1
            L:1/4
            K:C
            V:1
            C D|
            V:2
            E F|
            """
        let (tunebook, _) = try ABC.BaseParser().parse(Data(abc.utf8))
        let tune = try #require(tunebook.tunes.first)

        let results = try walker.walk(tune, fileHeader: tunebook.fileHeader)

        #expect(results.count == 3)
        #expect(results[0].identity == nil)
        #expect(results[1].identity != nil)
        #expect(results[2].identity != nil)

        var voice1Pitches: [Pitch] = []
        var voice2Pitches: [Pitch] = []

        results[1].context.noteTable.forEach { _, _, _, startPitch, _, _ in voice1Pitches.append(startPitch) }
        results[2].context.noteTable.forEach { _, _, _, startPitch, _, _ in voice2Pitches.append(startPitch) }

        #expect(voice1Pitches == ["C4", "D4"])
        #expect(voice2Pitches == ["E4", "F4"])
    }

    @Test
    func walk_singleVoice_returnsOneAccumulatorWithResolvedNotes() throws {
        let abc = """
            X:1
            L:1/4
            K:C
            C D E F|
            """
        let (tunebook, _) = try ABC.BaseParser().parse(Data(abc.utf8))
        let tune = try #require(tunebook.tunes.first)

        let results = try walker.walk(tune, fileHeader: tunebook.fileHeader)

        #expect(results.count == 1)
        #expect(results[0].identity == nil)

        var pitches: [Pitch] = []

        results[0].context.noteTable.forEach { _, _, _, startPitch, _, _ in pitches.append(startPitch) }

        #expect(pitches == ["C4", "D4", "E4", "F4"])
    }

    @Test
    func walk_tempoField_recordsTempoEvent() throws {
        let abc = """
            X:1
            L:1/4
            Q:1/4=120
            K:C
            C D|
            """
        let (tunebook, _) = try ABC.BaseParser().parse(Data(abc.utf8))
        let tune = try #require(tunebook.tunes.first)

        let results = try walker.walk(tune, fileHeader: tunebook.fileHeader)

        #expect(!results[0].context.tempoEvents.isEmpty)
    }

    @Test
    func walk_tieAcrossBarLine_mergesNotes() throws {
        let abc = """
            X:1
            L:1/4
            K:C
            C-|C D|
            """
        let (tunebook, _) = try ABC.BaseParser().parse(Data(abc.utf8))
        let tune = try #require(tunebook.tunes.first)

        let results = try walker.walk(tune, fileHeader: tunebook.fileHeader)

        var notes: [(pitch: Pitch, duration: BeatDuration)] = []

        results[0].context.noteTable.forEach { _, _, duration, startPitch, _, _ in notes.append((startPitch, duration)) }

        #expect(notes.count == 2)
        #expect(notes[0].pitch == "C4")
        #expect(notes[0].duration == BeatDuration(2))
        #expect(notes[1].pitch == "D4")
        #expect(notes[1].duration == BeatDuration(1))
    }
}
