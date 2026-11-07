// © 2026 John Gary Pusey (see LICENSE.md)

import IvorABC
@testable import IvorExtern
import Testing
import XestiTools

struct ABCImporterPlanTests {
}

// MARK: -

extension ABCImporterPlanTests {
    @Test
    func ranges_noRepeatsNoParts_returnsSingleFullRange() throws {
        let octave = try #require(ABCPitch.Octave(uintValue: 4))
        let pitch = ABCPitch(letter: .c, accidental: .natural, octave: octave)
        let length = try #require(ABCLength(numerator: 1))
        let note1 = ABCNote(pitch: pitch, length: length, tie: nil)
        let note2 = ABCNote(pitch: pitch, length: length, tie: nil)
        let items: [ABC.Importer.Item] = [.symbol(.note(note1)),
                                          .symbol(.note(note2))]
        let plan = ABC.Importer.Plan(items: items)

        let ranges = try plan.ranges()

        #expect(ranges == [0..<2])
    }

    @Test
    func ranges_partSequence_expandsPartsInOrder() throws {
        let repeatCount = try #require(ABCPartSequence.Item.RepeatCount(uintValue: 1))
        let sequence = try #require(ABCPartSequence(items: [.part(.a, repeatCount), .part(.b, repeatCount)]))
        let octave = try #require(ABCPitch.Octave(uintValue: 4))
        let pitchA = ABCPitch(letter: .c, accidental: .natural, octave: octave)
        let pitchB = ABCPitch(letter: .d, accidental: .natural, octave: octave)
        let length = try #require(ABCLength(numerator: 1))
        let noteA = ABCNote(pitch: pitchA, length: length, tie: nil)
        let noteB = ABCNote(pitch: pitchB, length: length, tie: nil)
        let items: [ABC.Importer.Item] = [.field(.parts(sequence)),
                                          .field(.part(.a)),
                                          .symbol(.note(noteA)),
                                          .field(.part(.b)),
                                          .symbol(.note(noteB))]
        let plan = ABC.Importer.Plan(items: items)

        let ranges = try plan.ranges()

        #expect(ranges == [0..<1, 2..<3, 4..<5])
    }

    @Test
    func ranges_partSequenceButNoPartMarkersInBody_fallsBackToWholeStream() throws {
        let repeatCount = try #require(ABCPartSequence.Item.RepeatCount(uintValue: 1))
        let sequence = try #require(ABCPartSequence(items: [.part(.a, repeatCount)]))
        let octave = try #require(ABCPitch.Octave(uintValue: 4))
        let pitch = ABCPitch(letter: .c, accidental: .natural, octave: octave)
        let length = try #require(ABCLength(numerator: 1))
        let note = ABCNote(pitch: pitch, length: length, tie: nil)
        let items: [ABC.Importer.Item] = [.field(.parts(sequence)),
                                          .symbol(.note(note))]
        let plan = ABC.Importer.Plan(items: items)

        let ranges = try plan.ranges()

        #expect(ranges == [0..<2])
    }

    @Test
    func ranges_partSequenceReferencesUndefinedPart_throws() throws {
        let repeatCount = try #require(ABCPartSequence.Item.RepeatCount(uintValue: 1))
        let sequence = try #require(ABCPartSequence(items: [.part(.b, repeatCount)]))
        let octave = try #require(ABCPitch.Octave(uintValue: 4))
        let pitch = ABCPitch(letter: .c, accidental: .natural, octave: octave)
        let length = try #require(ABCLength(numerator: 1))
        let note = ABCNote(pitch: pitch, length: length, tie: nil)
        let items: [ABC.Importer.Item] = [.field(.parts(sequence)),
                                          .field(.part(.a)),
                                          .symbol(.note(note))]
        let plan = ABC.Importer.Plan(items: items)

        #expect(throws: ABC.Error.self) {
            try plan.ranges()
        }
    }

    @Test(arguments: [("|: C D :|", "CDCD"),
                      ("|: C D | E F :|", "CDEFCDEF"),
                      ("C D | E F :|", "CDEFCDEF"),
                      ("|:C|D:|E|", "CDCDE"),
                      ("|: C [|] D :|", "CDCD"),
                      ("|: C :|: D :|", "CCDD")])
    func ranges_repeat_replaysItsWholeSection(body: String, expected: String) throws {
        #expect(try plannedLetters(body) == expected)
    }

    @Test(arguments: [("|: C || D :|", "CDD"),
                      ("|: C |] D :|", "CDD")])
    func ranges_repeat_returnsNoFurtherThanASectionBoundary(body: String, expected: String) throws {
        #expect(try plannedLetters(body) == expected)
    }

    @Test
    func ranges_repeatAfterEndings_startsItsOwnPasses() throws {
        #expect(try plannedLetters("|: C |1 D :|2 E |: F |1 G :|2 A :|") == "CDCEFGFA")
    }

    @Test
    func ranges_repeatExceedingSafetyCap_throws() throws {
        let playCount = try #require(ABCBarLine.PlayCount(uintValue: 2_000))
        let closeBar = try #require(ABCBarLine(kind: .repeat, precedingPlayCount: playCount))
        let items: [ABC.Importer.Item] = [.symbol(.barLine(closeBar))]
        let plan = ABC.Importer.Plan(items: items)

        #expect(throws: ABC.Error.self) {
            try plan.ranges()
        }
    }

    @Test
    func ranges_simpleRepeat_expandsToTwoPasses() throws {
        let openBar = try #require(ABCBarLine(kind: .repeat, followingPlayCount: 2))
        let closeBar = try #require(ABCBarLine(kind: .repeat, precedingPlayCount: 2))
        let octave = try #require(ABCPitch.Octave(uintValue: 4))
        let pitch = ABCPitch(letter: .c, accidental: .natural, octave: octave)
        let length = try #require(ABCLength(numerator: 1))
        let note = ABCNote(pitch: pitch, length: length, tie: nil)
        let items: [ABC.Importer.Item] = [.symbol(.barLine(openBar)),
                                          .symbol(.note(note)),
                                          .symbol(.barLine(closeBar))]
        let plan = ABC.Importer.Plan(items: items)

        let ranges = try plan.ranges()

        #expect(ranges == [0..<1, 1..<3, 1..<3])
    }

    @Test
    func ranges_variantEndingExceedingSafetyCap_throws() throws {
        let ending = try #require(ABCVariantEnding(endings: [1...2_000]))
        let closeBar = try #require(ABCBarLine(kind: .repeat, precedingPlayCount: 2))
        let items: [ABC.Importer.Item] = [.symbol(.variantEnding(ending)),
                                          .symbol(.barLine(closeBar))]
        let plan = ABC.Importer.Plan(items: items)

        #expect(throws: ABC.Error.self) {
            try plan.ranges()
        }
    }

    @Test(arguments: [("|: C [1 D :| [2 E |", "CDCE"),
                      ("|: C |1 D :|2 E |", "CDCE"),
                      ("|: C |1 D :|2 E :|", "CDCE"),
                      ("|: C D |1 E :|2 F |]", "CDECDF"),
                      ("|: C |1 D | E :|2 F | G |]", "CDECFG"),
                      ("|: C |1 D :| E |", "CDCE"),
                      ("|: C |1,3 D :|2 E :|", "CDCECD"),
                      ("|: C |1 D :|2 E || F |", "CDCEF")])
    func ranges_variantEndings_playOnTheirOwnPasses(body: String, expected: String) throws {
        #expect(try plannedLetters(body) == expected)
    }
}
