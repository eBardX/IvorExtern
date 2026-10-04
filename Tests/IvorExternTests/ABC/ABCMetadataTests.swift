// © 2026 John Gary Pusey (see LICENSE.md)

import Foundation
@testable import IvorExtern
import IvorModel
import IvorTiming
import IvorTuning
import Testing
import XestiTools

struct ABCMetadataTests {
}

// MARK: -

extension ABCMetadataTests {
    @Test
    func read_abc20Area_isLyricist() throws {
        let work = try _read("""
            %abc-2.0
            X:1
            T:Song
            A:Jane Poet
            K:C
            C
            """)

        #expect(work.metadata.credits == [Credit(name: "Jane Poet", role: .lyricist)].compactMap(\.self))
        #expect(work.metadata.remarks.isEmpty)
    }

    @Test
    func read_abc21Area_isAreaRemark() throws {
        let work = try _read("""
            %abc-2.1
            X:1
            T:Song
            A:Yorkshire
            K:C
            C
            """)

        #expect(work.metadata.credits.isEmpty)
        #expect(work.metadata.remarks == [Remark(text: "Yorkshire", label: "area")].compactMap(\.self))
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
            #expect(work.metadata.composers == ["Trad."])
            #expect(work.metadata.remarks == [Remark(text: "The Big Book", label: "book")].compactMap(\.self))
        }
    }

    @Test
    func read_stringFields_populateMetadata() throws {
        let work = try _read("""
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
        let metadata = work.metadata

        #expect(work.name == "The Main Title")
        #expect(metadata.title == "The Main Title")
        #expect(metadata.alternateTitles == ["Also Known As"])
        #expect(metadata.subtitles.isEmpty)
        #expect(metadata.credits == [Credit(name: "J. Smith", role: .composer),
                                     Credit(name: "A. Transcriber", role: .transcriber),
                                     Credit(name: "E. Ditor", role: .editor)].compactMap(\.self))
        #expect(metadata.rights == [RightsNotice(text: "© 2001 A. Transcriber", scope: .transcription)].compactMap(\.self))
        #expect(metadata.remarks == [Remark(text: "England; Yorkshire", label: "origin"),
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
    func write_metadata_writesStringFields() throws {
        let text = try _write(Work(name: "Sketch",
                                   content: .standardBeat([], TempoMap()),
                                   metadata: _sampleMetadata()))
        let lines = text.split(separator: "\n").map(String.init)

        #expect(lines.prefix(5) == ["%abc-2.1", "X:1", "T:Aubade", "T:Dawn Song", "T:Morning Piece"])
        #expect(lines.contains("C:J. Smith"))
        #expect(lines.contains("C:A. Poet (lyricist)"))
        #expect(lines.contains("Z:T. Scribe"))
        #expect(lines.contains("Z:abc-copyright © 2001 T. Scribe"))
        #expect(lines.contains("H:Collected in 1904 by a fiddler"))
        #expect(lines.contains("S:From a fiddler"))
        #expect(lines.contains("r:A plain remark"))
        #expect(lines.contains("N:mood: Wistful"))
        #expect(!text.contains("© 1998 Acme"))
        #expect(!text.contains("Collected Pieces"))
    }

    @Test
    func write_noTitle_writesWorkNameAsTitle() throws {
        let text = try _write(Work(name: "Sketch 3", content: .standardBeat([], TempoMap())))

        #expect(text.contains("T:Sketch 3\n"))
    }

    @Test
    func roundTrip_metadata_preservesWhatABCCanHold() throws {
        let part = Part<BeatTime, Pitch>(name: "Flute",
                                         noteTable: NoteTable())
        let work = Work(name: "Aubade",
                        content: .standardBeat([part], TempoMap()),
                        metadata: _sampleMetadata())
        let recovered = try roundTrip(work,
                                      exporter: ABC.Exporter(),
                                      importer: ABC.Importer(),
                                      fileFormat: .abc)
        let metadata = recovered.metadata

        #expect(metadata.title == "Aubade")
        #expect(metadata.alternateTitles == ["Dawn Song", "Morning Piece"])
        #expect(metadata.subtitles.isEmpty)
        #expect(metadata.parentWorkTitle == nil)
        #expect(metadata.credits == [Credit(name: "J. Smith", role: .composer),
                                     Credit(name: "A. Poet (lyricist)", role: .composer),
                                     Credit(name: "T. Scribe", role: .transcriber)].compactMap(\.self))
        #expect(metadata.rights == [RightsNotice(text: "© 2001 T. Scribe", scope: .transcription)].compactMap(\.self))
        #expect(metadata.remarks == [Remark(text: "Collected in 1904 by a fiddler", label: "history"),
                                     Remark(text: "From a fiddler", label: "source"),
                                     Remark(text: "A plain remark"),
                                     Remark(text: "mood: Wistful", label: "notes")].compactMap(\.self))
    }
}

// MARK: -

extension ABCMetadataTests {
    private func _read(_ abc: String) throws -> Work {
        let works = try ABC.Importer().read(from: FileWrapper(regularFileWithContents: Data(abc.utf8)), as: .abc)

        return try #require(works.first)
    }

    private func _sampleMetadata() -> Work.Metadata {
        Work.Metadata(title: "Aubade",
                      subtitles: ["Dawn Song"],
                      alternateTitles: ["Morning Piece"],
                      parentWorkTitle: "Collected Pieces",
                      credits: [Credit(name: "J. Smith", role: .composer),
                                Credit(name: "A. Poet", role: .lyricist),
                                Credit(name: "T. Scribe", role: .transcriber)].compactMap(\.self),
                      rights: [RightsNotice(text: "© 1998 Acme"),
                               RightsNotice(text: "© 2001 T. Scribe", scope: .transcription)].compactMap(\.self),
                      remarks: [Remark(text: "Collected in 1904\nby a fiddler", label: "history"),
                                Remark(text: "From a fiddler", label: "source"),
                                Remark(text: "A plain remark"),
                                Remark(text: "Wistful", label: "mood")].compactMap(\.self))
    }

    private func _write(_ work: Work) throws -> String {
        let file = try ABC.Exporter().write(works: [work], as: .abc)
        let data = try #require(file.regularFileContents)

        return try #require(String(data: data, encoding: .utf8))
    }
}
