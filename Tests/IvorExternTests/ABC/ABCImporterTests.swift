// © 2025–2026 John Gary Pusey (see LICENSE.md)

import Foundation
@testable import IvorExtern
import IvorModel
import IvorTiming
import IvorTuning
import Testing
import XestiNumbers
import XestiTools

// swiftlint:disable file_length

struct ABCImporterTests {
}

// MARK: -

extension ABCImporterTests {
    @Test
    func read_abc20Area_isLyricist() throws {
        let work = try readABC("""
            %abc-2.0
            X:1
            T:Song
            A:Jane Poet
            K:C
            C
            """)

        #expect(work.info.credits == [Credit(name: "Jane Poet", role: .lyricist)].compactMap(\.self))
        #expect(work.info.remarks.isEmpty)
    }

    @Test
    func read_abc21Area_isAreaRemark() throws {
        let work = try readABC("""
            %abc-2.1
            X:1
            T:Song
            A:Yorkshire
            K:C
            C
            """)

        #expect(work.info.credits.isEmpty)
        #expect(work.info.remarks == [Remark(text: "Yorkshire", label: "area")].compactMap(\.self))
    }

    @Test
    func read_abcCopyrightAndEditedByDirectives_populateInfo() throws {
        let work = try readABC("""
            X:1
            T:Tune
            %%abc-copyright 1998 Acme
            %%abc-edited-by J. Editor
            K:C
            C
            """)

        #expect(work.info.rights.map(\.text) == ["1998 Acme"])
        #expect(work.info.rights.first?.scope == .transcription)
        #expect(work.info.credits.map(\.name) == ["J. Editor"])
        #expect(work.info.credits.first?.role == .editor)
    }

    @Test
    func read_bareMidiChannelDirective_putsChannelExtraOnPart() throws {
        let abc = """
            X:1
            T:Channel-Only Tune
            L:1/4
            K:C
            %%MIDI channel 3
            C D E F|
            """
        let wrapper = FileWrapper(regularFileWithContents: Data(abc.utf8))
        let works = try ABC.Importer().read(from: wrapper, as: .abc)
        let work = try #require(works.first)
        let parts = try #require(standardBeatParts(of: work))

        #expect(parts.first?.instrumentTable.isEmpty == true)

        let foundChannel = intValue(parts.first?.extras, .midiChannel)

        #expect(foundChannel == 3)
    }

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
    func read_dedicationNotes_isDedication() throws {
        let work = try readABC("""
            %abc-2.1
            X:1
            T:Song
            N:Dedication: For Anna
            N:dedication: For Ben
            K:C
            C
            """)

        #expect(work.info.dedication == "For Anna")
        #expect(work.info.remarks == [Remark(text: "dedication: For Ben", label: "notes")].compactMap(\.self))
    }

    @Test
    func read_dynamicChange_isAStep() throws {
        let part = try #require(standardBeatParts(of: readABC("""
            X:1
            T:Tune
            L:1/4
            K:C
            !p! C D !f! E
            """))?.first)

        #expect(part.dynamicMap.map(\.time) == [.zero, BeatTime(2), BeatTime(2)])
        #expect(part.dynamicMap.map(\.dynamic) == [.p, .p, .f])
    }

    @Test
    func read_dynamicWithoutACanonicalLevel_keepsItsMark() throws {
        let part = try #require(standardBeatParts(of: readABC("""
            X:1
            T:Tune
            L:1/4
            K:C
            !p! C !sfz! D
            """))?.first)
        let marks = part.dynamicMap.map { stringValue($0.extras, .dynamicMark) }

        #expect(part.dynamicMap.map(\.time) == [.zero, BeatTime(1)])
        #expect(part.dynamicMap.map(\.dynamic) == [.p, .p])
        #expect(marks == [nil, "sfz"])
    }

    @Test
    func read_emptyData_throws() {
        let wrapper = FileWrapper(regularFileWithContents: Data())

        #expect(throws: (any Error).self) {
            try ABC.Importer().read(from: wrapper, as: .abc)
        }
    }

    @Test
    func read_fileHeaderFields_applyToEveryTune() throws {
        let abc = """
            %abc-2.1
            C:Trad.
            B:The Big Book

            X:1
            T:First
            K:C
            C

            X:2
            T:Second
            K:C
            D
            """
        let works = try ABC.Importer().read(from: FileWrapper(regularFileWithContents: Data(abc.utf8)), as: .abc)

        #expect(works.count == 2)

        for work in works {
            #expect(work.info.composers == ["Trad."])
            #expect(work.info.remarks == [Remark(text: "The Big Book", label: "book")].compactMap(\.self))
        }
    }

    @Test
    func read_hairpin_leavesAGlideBetweenItsEndpoints() throws {
        let part = try #require(standardBeatParts(of: readABC("""
            X:1
            T:Tune
            L:1/4
            K:C
            !<(! C D !<)! E
            """))?.first)

        #expect(part.dynamicMap.map(\.time) == [.zero, BeatTime(2)])
        #expect(part.dynamicMap.map(\.dynamic) == [.mp, .mf])
    }

    @Test
    func read_midiProgramAndStandaloneChannelDirectives_programChannelTakesPriority() throws {
        let abc = """
            X:1
            T:Both Directives Tune
            L:1/4
            K:C
            %%MIDI channel 3
            %%MIDI program 2 40
            C D E F|
            """
        let wrapper = FileWrapper(regularFileWithContents: Data(abc.utf8))
        let works = try ABC.Importer().read(from: wrapper, as: .abc)
        let work = try #require(works.first)
        let parts = try #require(standardBeatParts(of: work))

        let foundChannel = intValue(parts.first?.extras, .midiChannel)

        #expect(parts.first?.instrumentTable[.zero] == Instrument("Violin"))
        #expect(foundChannel == 2)
    }

    @Test
    func read_midiProgramBaseOne_countsProgramsFromOne() throws {
        let abc = """
            %%MIDI programbase 1

            X:1
            T:Standard Numbering
            L:1/4
            K:C
            %%MIDI program 41
            C D E F|
            """
        let wrapper = FileWrapper(regularFileWithContents: Data(abc.utf8))
        let work = try #require(ABC.Importer().read(from: wrapper, as: .abc).first)
        let parts = try #require(standardBeatParts(of: work))

        var programs: [Int?] = []

        for entry in parts.first?.instrumentTable ?? InstrumentTable() {
            programs.append(intValue(entry.extras, .midiProgram))
        }

        #expect(parts.first?.instrumentTable[.zero] == Instrument("Violin"))
        #expect(programs == [41])
    }

    @Test
    func read_midiProgramDirective_populatesInstrumentTable() throws {
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

        #expect(parts.first?.instrumentTable[.zero] == Instrument("Violin"))
    }

    @Test
    func read_midiProgramDirectivesAfterInlineVoiceFields_assignEachVoice() throws {
        let parts = try #require(standardBeatParts(of: readABC("""
            X:1
            T:Tune
            L:1/4
            K:C
            [V:A] C
            %%MIDI program 40
            [V:B] D
            %%MIDI program 41
            """)))

        #expect(parts.map { $0.instrumentTable.map { intValue($0.extras, .midiProgram) } } == [[41], [42]])
    }

    @Test
    func read_midiProgramDirectivesInVoiceBodies_assignEachVoice() throws {
        let abc = """
            X:1
            T:Duet
            L:1/4
            V:1
            V:2
            K:C
            V:1
            %%MIDI program 73
            c d e f|
            V:2
            %%MIDI program 70
            C, D, E, F,|
            """
        let wrapper = FileWrapper(regularFileWithContents: Data(abc.utf8))
        let work = try #require(ABC.Importer().read(from: wrapper, as: .abc).first)
        let parts = try #require(standardBeatParts(of: work))

        #expect(parts.map { $0.instrumentTable[.zero] } == [Instrument("Flute"), Instrument("Bassoon")])
    }

    @Test
    func read_midiProgramDirectiveWithChannel_putsChannelExtraOnPart() throws {
        let abc = """
            X:1
            T:Instrument Tune
            L:1/4
            K:C
            %%MIDI program 5 41
            C D E F|
            """
        let wrapper = FileWrapper(regularFileWithContents: Data(abc.utf8))
        let works = try ABC.Importer().read(from: wrapper, as: .abc)
        let work = try #require(works.first)
        let parts = try #require(standardBeatParts(of: work))

        let foundChannel = intValue(parts.first?.extras, .midiChannel)

        #expect(foundChannel == 5)
    }

    @Test
    func read_midiVoiceDirectiveInBody_assignsCurrentVoice() throws {
        // The example in §11.2 of the ABC 2.1 standard.
        let abc = """
            X:1
            T:Organ Tune
            L:1/4
            V:Rueckpos
            V:Organo
            K:C
            V:Rueckpos
            %%MIDI voice instrument=53 bank=2
            C D E F|
            V:Organo
            %%MIDI voice instrument=73
            G A B c|
            """
        let wrapper = FileWrapper(regularFileWithContents: Data(abc.utf8))
        let work = try #require(ABC.Importer().read(from: wrapper, as: .abc).first)
        let rueckpos = try namedStandardPart(work, "Rueckpos")
        let organo = try namedStandardPart(work, "Organo")

        #expect(rueckpos.instrumentTable[.zero] == Instrument("Choir Aahs"))
        #expect(organo.instrumentTable[.zero] == Instrument("Piccolo"))

        var banks: [Int?] = []

        for entry in rueckpos.instrumentTable {
            banks.append(intValue(entry.extras, .midiBank))
        }

        for entry in organo.instrumentTable {
            banks.append(intValue(entry.extras, .midiBank))
        }

        #expect(banks == [1, nil])
    }

    @Test
    func read_midiVoiceDirectivesInHeader_namedVoiceWinsOverFallbackAndProgram() throws {
        let abc = """
            X:1
            T:Header Tune
            L:1/4
            %%MIDI program 2 41
            %%MIDI voice Tb instrument=59
            %%MIDI voice instrument=43
            V:Tb
            V:Vc
            K:C
            V:Tb
            C, D, E, F,|
            V:Vc
            C D E F|
            """
        let wrapper = FileWrapper(regularFileWithContents: Data(abc.utf8))
        let work = try #require(ABC.Importer().read(from: wrapper, as: .abc).first)
        let tuba = try namedStandardPart(work, "Tb")
        let cello = try namedStandardPart(work, "Vc")

        #expect(tuba.instrumentTable[.zero] == Instrument("Tuba"))
        #expect(cello.instrumentTable[.zero] == Instrument("Cello"))

        #expect(intValue(tuba.extras, .midiChannel) == 2)
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
        // and isn't dropped. Being unnamed in a multi-part work, it takes
        // the positional "Voice N" fallback.
        #expect(parts.map(\.name) == ["Voice 1", "Melody", "Bass"])

        let implicitPart = try #require(parts.first { $0.name == "Voice 1" })

        #expect(notes(in: implicitPart).map(\.pitch) == ["G4", "A4"])
    }

    @Test
    func read_noPedMarks_hasNoPedals() throws {
        #expect(try abcPedalPart("C D E F").pedals.isEmpty)
    }

    @Test
    func read_pedAndPedUp_populateSustainTable() throws {
        let part = try abcPedalPart("C !ped!D !ped-up!E F")

        #expect(Array(part.pedals.keys) == [.sustain])
        #expect(part.pedals[.sustain]?.map(\.time) == [1, 2])
        #expect(part.pedals[.sustain]?.map(\.level) == [.down, .up])
        #expect(part.noteCount == 4)
    }

    @Test
    func read_pedMarks_areNotArticulations() throws {
        let extras = try abcNoteExtras("""
            X:1
            T:Test
            M:4/4
            L:1/8
            K:C
            !ped!C D !ped-up!E F
            """)

        for noteExtras in extras {
            #expect(stringValue(noteExtras, .articulation) == nil)
        }
    }

    @Test
    func read_repeatWithBarLineInside_replaysWholeSection() throws {
        let part = try #require(standardBeatParts(of: readABC("""
            X:1
            T:Tune
            L:1/4
            K:C
            |: C D | E F :|
            """))?.first)

        #expect(part.noteTable.map(\.attack) == (0..<8).map { BeatTime(Number($0)) })
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
    func read_stringFields_populateInfo() throws {
        let work = try readABC("""
            %abc-2.1
            X:1
            T:The Main Title
            T:Also Known As
            C:J. Smith
            O:England; Yorkshire
            R:reel
            B:Book One
            D:Some LP
            F:http://example.com/tune.abc
            G:fiddle
            H:Collected in 1904
            N:Play it fast
            S:From a fiddler
            Z:A. Transcriber
            Z:abc-edited-by E. Ditor
            Z:abc-copyright © 2001 A. Transcriber
            r:An aside
            K:C
            C
            """)
        let info = work.info

        #expect(work.name == "The Main Title")
        #expect(info.title == "The Main Title")
        #expect(info.alternateTitles == ["Also Known As"])
        #expect(info.subtitles.isEmpty)
        #expect(info.credits == [Credit(name: "J. Smith", role: .composer),
                                 Credit(name: "A. Transcriber", role: .transcriber),
                                 Credit(name: "E. Ditor", role: .editor)].compactMap(\.self))
        #expect(info.rights == [RightsNotice(text: "© 2001 A. Transcriber", scope: .transcription)].compactMap(\.self))
        #expect(info.remarks == [Remark(text: "England; Yorkshire", label: "origin"),
                                 Remark(text: "reel", label: "rhythm"),
                                 Remark(text: "Book One", label: "book"),
                                 Remark(text: "Some LP", label: "discography"),
                                 Remark(text: "http://example.com/tune.abc", label: "file URL"),
                                 Remark(text: "fiddle", label: "group"),
                                 Remark(text: "Collected in 1904", label: "history"),
                                 Remark(text: "Play it fast", label: "notes"),
                                 Remark(text: "From a fiddler", label: "source"),
                                 Remark(text: "An aside")].compactMap(\.self))
    }

    @Test
    func read_tempoChangeOnItsOwnLine_isAStep() throws {
        let work = try readABC("""
            X:1
            T:Tune
            L:1/4
            Q:1/4=120
            K:C
            C
            Q:1/4=60
            D
            """)

        guard case let .standardBeat(_, tempoMap) = work.content
        else { Issue.record("Expected standardBeat content"); return }

        #expect(tempoMap.map(\.beatTime) == [.zero, BeatTime(1), BeatTime(1)])
        #expect(tempoMap.map(\.tempo.uintValue) == [120, 120, 60])
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
    func read_voiceNameWithLineBreak_joinsLinesWithSpace() throws {
        let abc = #"""
            X:1
            T:Line Break
            L:1/4
            K:C
            V:1 nm="Tenor\nSax"
            C D E F|
            """#
        let wrapper = FileWrapper(regularFileWithContents: Data(abc.utf8))
        let works = try ABC.Importer().read(from: wrapper, as: .abc)
        let work = try #require(works.first)
        let parts = try #require(standardBeatParts(of: work))

        #expect(parts.map(\.name) == ["Tenor Sax"])
    }

    @Test
    func read_voiceNumberIDsWithoutNames_fallBackToVoiceN() throws {
        let abc = "X:1\nT:Numbered\nL:1/4\nK:C\nV:1\nC D E F|\nV:3\nG A B c|\n"
        let wrapper = FileWrapper(regularFileWithContents: Data(abc.utf8))
        let work = try #require(try ABC.Importer().read(from: wrapper, as: .abc).first)

        #expect(try #require(standardBeatParts(of: work)).map(\.name) == ["Voice 1", "Voice 2"])
    }

    @Test
    func read_voiceWithoutNameOrSubname_usesVoiceID() throws {
        let abc = """
            X:1
            T:Unnamed Voice
            L:1/4
            K:C
            V:Tenor
            C D E F|
            """
        let wrapper = FileWrapper(regularFileWithContents: Data(abc.utf8))
        let works = try ABC.Importer().read(from: wrapper, as: .abc)
        let work = try #require(works.first)
        let parts = try #require(standardBeatParts(of: work))
        let part = try #require(parts.first { $0.name == "Tenor" })

        #expect(notes(in: part).map(\.pitch) == ["C4", "D4", "E4", "F4"])
    }

    @Test
    func readableFileFormats_containsABC() {
        #expect(ABC.Importer().readableFileFormats.contains(.abc))
    }
}

// swiftlint:enable file_length
