// © 2026 John Gary Pusey (see LICENSE.md)

import Foundation
import IvorABC
@testable import IvorExtern
import IvorModel
import IvorTiming
import IvorTuning
import Testing
import XestiNumbers
import XestiTools

struct ABCImporterWalkerTests {
    private let walker = ABC.Importer.Walker()
}

// MARK: -

extension ABCImporterWalkerTests {
    @Test
    func walk_accentDecoration_attachesFlagToNextNote() throws {
        let abc = """
            X:1
            L:1/4
            K:C
            !accent!C D|
            """
        let (tunebook, _) = try ABC.BaseParser().parse(Data(abc.utf8))
        let tune = try #require(tunebook.tunes.first)

        let results = try walker.walk(tune, fileHeader: tunebook.fileHeader)

        #expect(results[0].context.noteTable.contains { hasFlag($0.extras, .accent) })
    }

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

        for note in results[0].context.noteTable {
            durations.append(note.duration)
        }

        #expect(durations == [BeatDuration(Number(numerator: 3, denominator: 2)),
                              BeatDuration(Number(numerator: 1, denominator: 2))])
    }

    @Test
    func walk_defaultShorthands_resolveToStandardDecorations() throws {
        let notes = try abcNoteExtras("""
            X:1
            L:1/4
            K:C
            TC ~D HE uF vG LA|
            """)

        #expect(notes.count == 6)
        #expect(hasFlag(notes[0], .trill))
        #expect(stringValue(notes[1], .articulation) == "roll")
        #expect(hasFlag(notes[2], .fermata))
        #expect(hasFlag(notes[3], .upBow))
        #expect(hasFlag(notes[4], .downBow))
        #expect(hasFlag(notes[5], .accent))
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
    func walk_fileHeaderShorthand_appliesToEveryTuneUnlessRedefined() throws {
        let abc = """
            U: W = !tenuto!

            X:1
            L:1/4
            K:C
            U: W = !accent!
            WC|

            X:2
            L:1/4
            K:C
            WC|
            """
        let (tunebook, _) = try ABC.BaseParser().parse(Data(abc.utf8))

        #expect(tunebook.tunes.count == 2)

        let first = try walker.walk(tunebook.tunes[0], fileHeader: tunebook.fileHeader)
        let second = try walker.walk(tunebook.tunes[1], fileHeader: tunebook.fileHeader)
        let firstNote = try #require(first[0].context.noteTable.first)
        let secondNote = try #require(second[0].context.noteTable.first)

        #expect(hasFlag(firstNote.extras, .accent))
        #expect(!hasFlag(firstNote.extras, .tenuto))
        #expect(hasFlag(secondNote.extras, .tenuto))
        #expect(!hasFlag(secondNote.extras, .accent))
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
    func walk_inlineUserDefinedShorthand_takesEffectMidLine() throws {
        let notes = try abcNoteExtras("""
            X:1
            L:1/4
            K:C
            TC [U:T=!accent!] TD|
            """)

        #expect(notes.count == 2)
        #expect(hasFlag(notes[0], .trill))
        #expect(hasFlag(notes[1], .accent))
        #expect(!hasFlag(notes[1], .trill))
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

        for note in results[0].context.noteTable {
            pitches.append(note.startPitch)
        }

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

        for note in results[1].context.noteTable {
            voice1Pitches.append(note.startPitch)
        }
        for note in results[2].context.noteTable {
            voice2Pitches.append(note.startPitch)
        }

        #expect(voice1Pitches == ["C4", "D4"])
        #expect(voice2Pitches == ["E4", "F4"])
    }

    @Test
    func walk_shorthandMappedToAnnotation_isDropped() throws {
        let notes = try abcNoteExtras("""
            X:1
            L:1/4
            K:C
            U: W = "^hello"
            WC|
            """)

        #expect(notes.count == 1)
        #expect(notes[0] == nil)
    }

    @Test
    func walk_shorthandMappedToDynamic_recordsStepDynamicEvent() throws {
        let abc = """
            X:1
            L:1/4
            K:C
            U: W = !ff!
            C WD|
            """
        let (tunebook, _) = try ABC.BaseParser().parse(Data(abc.utf8))
        let tune = try #require(tunebook.tunes.first)

        let results = try walker.walk(tune, fileHeader: tunebook.fileHeader)
        let events = results[0].context.dynamicEvents

        #expect(events.count == 1)
        #expect(events.first?.beatTime == BeatTime(1))
        #expect(events.first?.dynamic == .ff)
        #expect(events.first?.kind == .step)
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

        for note in results[0].context.noteTable {
            pitches.append(note.startPitch)
        }

        #expect(pitches == ["C4", "D4", "E4", "F4"])
    }

    @Test
    func walk_slur_attachesStartAndEndFlags() throws {
        let abc = """
            X:1
            L:1/4
            K:C
            (C D)|
            """
        let (tunebook, _) = try ABC.BaseParser().parse(Data(abc.utf8))
        let tune = try #require(tunebook.tunes.first)

        let results = try walker.walk(tune, fileHeader: tunebook.fileHeader)

        var flags: [(start: Bool, end: Bool)] = []

        for note in results[0].context.noteTable {
            flags.append((hasFlag(note.extras, .slurStart), hasFlag(note.extras, .slurEnd)))
        }

        #expect(flags.count == 2)
        #expect(flags[0] == (true, false))
        #expect(flags[1] == (false, true))
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

        for note in results[0].context.noteTable {
            notes.append((note.startPitch, note.duration))
        }

        #expect(notes.count == 2)
        #expect(notes[0].pitch == "C4")
        #expect(notes[0].duration == BeatDuration(2))
        #expect(notes[1].pitch == "D4")
        #expect(notes[1].duration == BeatDuration(1))
    }

    @Test
    func walk_unassignedShorthand_isDropped() throws {
        let notes = try abcNoteExtras("""
            X:1
            L:1/4
            K:C
            WC|
            """)

        #expect(notes.count == 1)
        #expect(notes[0] == nil)
    }

    @Test
    func walk_unrecognizedDecoration_recordsMarkedStepAtPreviousLevel() throws {
        let abc = """
            X:1
            L:1/4
            K:C
            !sfz!C D|
            """
        let (tunebook, _) = try ABC.BaseParser().parse(Data(abc.utf8))
        let tune = try #require(tunebook.tunes.first)

        let results = try walker.walk(tune, fileHeader: tunebook.fileHeader)
        let events = results[0].context.dynamicEvents

        #expect(events.count == 1)
        #expect(events.first?.beatTime == .zero)
        #expect(events.first?.dynamic == .mp)
        #expect(events.first?.kind == .step)
        #expect(events.first?.mark == "sfz")
    }

    @Test
    func walk_userDefinedShorthand_overridesDefault() throws {
        let notes = try abcNoteExtras("""
            X:1
            L:1/4
            K:C
            U: T = !staccato!
            TC|
            """)

        #expect(notes.count == 1)
        #expect(hasFlag(notes[0], .staccato))
        #expect(!hasFlag(notes[0], .trill))
    }

    @Test
    func walk_userDefinedShorthandNil_deassignsSymbol() throws {
        let notes = try abcNoteExtras("""
            X:1
            L:1/4
            K:C
            U: T = !nil!
            TC|
            """)

        #expect(notes.count == 1)
        #expect(notes[0] == nil)
    }
}
