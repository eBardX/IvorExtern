// © 2025–2026 John Gary Pusey (see LICENSE.md)

import Foundation
@testable import IvorExtern
import IvorModel
import IvorTiming
import IvorTuning
import Testing
import XestiNumbers
import XestiTools

struct ABCImporterTests {
}

// MARK: -

extension ABCImporterTests {
    @Test
    func read_chordProducesSimultaneousNotes() throws {
        let abc = """
            X:1
            T:Chord Tune
            L:1/4
            K:C
            [CEG]2 D|
            """
        let wrapper = FileWrapper(regularFileWithContents: Data(abc.utf8))
        let works = try ABC.Importer().read(from: wrapper, as: .abc)
        let work = try #require(works.first)
        let parts = try #require(standardBeatParts(of: work))
        let part = try #require(parts.first)
        let notes = notes(in: part)

        #expect(notes.count == 4)
        #expect(notes[0].attack == BeatTime(0))
        #expect(notes[0].duration == BeatDuration(2))
        #expect(Set(notes[0..<3].map(\.pitch)) == ["C4", "E4", "G4"])
        #expect(notes[3].attack == BeatTime(2))
        #expect(notes[3].pitch == "D4")
    }

    @Test
    func read_chordWithDifferingMemberLengths_honorsEachNotesOwnLengthAndAdvancesByTheFirst() throws {
        let abc = """
            X:1
            T:Mixed-Length Chord Tune
            L:1/4
            K:C
            [C2E4G] D|
            """
        let wrapper = FileWrapper(regularFileWithContents: Data(abc.utf8))
        let works = try ABC.Importer().read(from: wrapper, as: .abc)
        let work = try #require(works.first)
        let parts = try #require(standardBeatParts(of: work))
        let part = try #require(parts.first)
        let notes = notes(in: part)
        let byPitch = Dictionary(uniqueKeysWithValues: notes.map { ($0.pitch, $0) })

        // Per §4.17 of the ABC 2.1 standard, notes within an unmarked chord
        // keep their own individually written lengths, and the chord
        // occupies the position of its first note (here, C2, a half note).
        #expect(notes.count == 4)
        #expect(byPitch["C4"]?.duration == BeatDuration(2))
        #expect(byPitch["E4"]?.duration == BeatDuration(4))
        #expect(byPitch["G4"]?.duration == BeatDuration(1))
        #expect(byPitch["D4"]?.attack == BeatTime(2))
    }

    @Test
    func read_chordWithOuterAndInnerLengthModifiers_multipliesThemTogether() throws {
        let abc = """
            X:1
            T:Combined-Modifier Chord Tune
            L:1/4
            K:C
            [C2E2G2]3 D|
            """
        let wrapper = FileWrapper(regularFileWithContents: Data(abc.utf8))
        let works = try ABC.Importer().read(from: wrapper, as: .abc)
        let work = try #require(works.first)
        let parts = try #require(standardBeatParts(of: work))
        let part = try #require(parts.first)
        let notes = notes(in: part)

        // Per §4.17 of the ABC 2.1 standard, `[C2E2G2]3` means the same as
        // `[CEG]6`.
        #expect(notes.count == 4)
        #expect(notes[0..<3].allSatisfy { $0.duration == BeatDuration(6) })
        #expect(notes[3].attack == BeatTime(6))
    }

    @Test
    func read_emptyData_throws() {
        let wrapper = FileWrapper(regularFileWithContents: Data())

        #expect(throws: (any Error).self) {
            try ABC.Importer().read(from: wrapper, as: .abc)
        }
    }

    @Test
    func read_midiProgramDirective_populatesInstrumentMap() throws {
        let abc = """
            X:1
            T:Instrument Tune
            L:1/4
            K:C
            %%MIDI program 40
            C D E F|
            """
        let wrapper = FileWrapper(regularFileWithContents: Data(abc.utf8))
        let works = try ABC.Importer().read(from: wrapper, as: .abc)
        let work = try #require(works.first)
        let parts = try #require(standardBeatParts(of: work))

        #expect(parts.first?.instrumentMap[.zero] == Instrument("Violin"))
    }

    @Test
    func read_missingKeyField_throwsValidationFailure() {
        let abc = """
            X:1
            T:No Key
            C D E F|
            """
        let wrapper = FileWrapper(regularFileWithContents: Data(abc.utf8))

        #expect(throws: (any Error).self) {
            try ABC.Importer().read(from: wrapper, as: .abc)
        }
    }

    @Test
    func read_multiVoiceTune_producesOneNamedPartPerDeclaredVoice() throws {
        let abc = """
            X:1
            T:Two Voices
            L:1/4
            K:C
            V:1 name="Melody"
            V:2 name="Bass"
            V:1
            C D E F|
            V:2
            c B A G|
            """
        let wrapper = FileWrapper(regularFileWithContents: Data(abc.utf8))
        let works = try ABC.Importer().read(from: wrapper, as: .abc)
        let work = try #require(works.first)
        let parts = try #require(standardBeatParts(of: work))

        // No content precedes the first `V:` field, so the implicit voice
        // it would otherwise land in stays empty and is dropped.
        #expect(parts.map(\.name) == ["Melody", "Bass"])

        let melodyPart = try #require(parts.first { $0.name == "Melody" })
        let bassPart = try #require(parts.first { $0.name == "Bass" })

        #expect(notes(in: melodyPart).map(\.pitch) == ["C4", "D4", "E4", "F4"])
        #expect(notes(in: bassPart).map(\.pitch) == ["C5", "B4", "A4", "G4"])
    }

    @Test
    func read_multiVoiceTuneWithContentBeforeFirstVoiceField_keepsTheImplicitLeadingPart() throws {
        let abc = """
            X:1
            T:Two Voices
            L:1/4
            K:C
            G A|
            V:1 name="Melody"
            C D E F|
            V:2 name="Bass"
            c B A G|
            """
        let wrapper = FileWrapper(regularFileWithContents: Data(abc.utf8))
        let works = try ABC.Importer().read(from: wrapper, as: .abc)
        let work = try #require(works.first)
        let parts = try #require(standardBeatParts(of: work))

        // Content before the first `V:` field lands in the implicit voice,
        // so — unlike the no-leading-content case above — it isn't empty
        // and isn't dropped.
        #expect(parts.map(\.name) == ["", "Melody", "Bass"])

        let implicitPart = try #require(parts.first { $0.name.isEmpty })

        #expect(notes(in: implicitPart).map(\.pitch) == ["G4", "A4"])
    }

    @Test
    func read_restAdvancesTimeWithoutInsertingNote() throws {
        let abc = """
            X:1
            T:Rest Tune
            L:1/4
            K:C
            C z D|
            """
        let wrapper = FileWrapper(regularFileWithContents: Data(abc.utf8))
        let works = try ABC.Importer().read(from: wrapper, as: .abc)
        let work = try #require(works.first)
        let parts = try #require(standardBeatParts(of: work))
        let part = try #require(parts.first)
        let notes = notes(in: part)

        #expect(notes.count == 2)
        #expect(notes[0].attack == BeatTime(0))
        #expect(notes[0].pitch == "C4")
        #expect(notes[1].attack == BeatTime(2))
        #expect(notes[1].pitch == "D4")
    }

    @Test
    func read_singleVoiceTune_producesNotesWithExpectedPitchesAndDurations() throws {
        let abc = """
            X:1
            T:Test Tune
            L:1/4
            K:C
            C D E F|
            """
        let wrapper = FileWrapper(regularFileWithContents: Data(abc.utf8))
        let works = try ABC.Importer().read(from: wrapper, as: .abc)

        #expect(works.count == 1)

        let work = try #require(works.first)

        #expect(work.name == "Test Tune")

        let parts = try #require(standardBeatParts(of: work))

        #expect(parts.count == 1)

        let part = try #require(parts.first)
        let notes = notes(in: part)
        let quarter = BeatDuration(1)

        #expect(notes.count == 4)
        #expect(notes.map(\.pitch) == ["C4", "D4", "E4", "F4"])
        #expect(notes.allSatisfy { $0.duration == quarter })
        #expect(notes.map(\.attack) == [BeatTime(0),
                                        BeatTime(1),
                                        BeatTime(2),
                                        BeatTime(3)])
    }

    @Test
    func read_tempoField_populatesTempoMap() throws {
        let abc = """
            X:1
            T:Tempo Tune
            L:1/4
            Q:1/4=144
            K:C
            C D E F|
            """
        let wrapper = FileWrapper(regularFileWithContents: Data(abc.utf8))
        let works = try ABC.Importer().read(from: wrapper, as: .abc)
        let work = try #require(works.first)

        guard case let .standardBeat(_, tempoMap) = work.content
        else { Issue.record("Expected standardBeat content"); return }

        #expect(!tempoMap.isEmpty)
    }

    @Test
    func read_tuneWithoutVoiceField_producesEmptyPartName() throws {
        let abc = """
            X:1
            T:No Voice Field
            L:1/4
            K:C
            C D E F|
            """
        let wrapper = FileWrapper(regularFileWithContents: Data(abc.utf8))
        let works = try ABC.Importer().read(from: wrapper, as: .abc)
        let work = try #require(works.first)
        let parts = try #require(standardBeatParts(of: work))
        let part = try #require(parts.first)

        #expect(part.name.isEmpty)
    }

    @Test
    func read_unsupportedFormat_throws() {
        let wrapper = FileWrapper(regularFileWithContents: Data())

        #expect(throws: (any Error).self) {
            try ABC.Importer().read(from: wrapper, as: .midi)
        }
    }

    @Test
    func read_voiceWithoutNameOrSubname_usesVoiceID() throws {
        let abc = """
            X:1
            T:Unnamed Voice
            L:1/4
            K:C
            V:1
            C D E F|
            """
        let wrapper = FileWrapper(regularFileWithContents: Data(abc.utf8))
        let works = try ABC.Importer().read(from: wrapper, as: .abc)
        let work = try #require(works.first)
        let parts = try #require(standardBeatParts(of: work))
        let part = try #require(parts.first { $0.name == "1" })

        #expect(notes(in: part).map(\.pitch) == ["C4", "D4", "E4", "F4"])
    }

    @Test
    func readableFileFormats_containsABC() {
        #expect(ABC.Importer().readableFileFormats.contains(.abc))
    }
}
