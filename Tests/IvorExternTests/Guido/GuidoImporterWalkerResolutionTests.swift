// © 2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import IvorGMN
import Testing
import XestiNumbers

struct GuidoImporterWalkerResolutionTests {
}

// MARK: -

extension GuidoImporterWalkerResolutionTests {
    @Test
    func resolveChordMembers_marksTiedSegments() throws {
        let tie = try #require(GMNTie(span: .begin))
        let tied = try #require(GMNChord.Segment(symbols: [.tag(.tie(tie)), .note(makeGMNNote(name: .c))]))
        let plain = try #require(GMNChord.Segment(symbols: [.note(makeGMNNote(name: .e))]))
        let chord = try #require(GMNChord(segments: [tied, plain]))
        var context = Guido.Importer.Context()

        let members = try Guido.Importer.Walker.resolveChordMembers(chord, &context)

        #expect(members.map(\.note.pitch.name) == [.c, .e])
        #expect(members.map(\.isTied) == [true, false])
    }

    @Test
    func resolveChordMembers_restSegment_hasNoMember() throws {
        let rest = GMNRest(duration: GMNDuration(numerator: 1, denominator: 2))
        let restSegment = try #require(GMNChord.Segment(symbols: [.rest(rest)]))
        let noteSegment = try #require(GMNChord.Segment(symbols: [.note(makeGMNNote(duration: nil))]))
        let chord = try #require(GMNChord(segments: [restSegment, noteSegment]))
        var context = Guido.Importer.Context()

        let members = try Guido.Importer.Walker.resolveChordMembers(chord, &context)

        #expect(members.count == 1)
        #expect(members.first?.note.duration.numberValue == Number(numerator: 1, denominator: 2))
    }

    @Test
    func resolvedAccidental_eachCase() {
        #expect(Guido.Importer.Walker.resolvedAccidental(.doubleFlat) == .doubleFlat)
        #expect(Guido.Importer.Walker.resolvedAccidental(.doubleSharp) == .doubleSharp)
        #expect(Guido.Importer.Walker.resolvedAccidental(.flat) == .flat)
        #expect(Guido.Importer.Walker.resolvedAccidental(.impliedSharp) == .sharp)
        #expect(Guido.Importer.Walker.resolvedAccidental(.omitted) == .natural)
        #expect(Guido.Importer.Walker.resolvedAccidental(.sharp) == .sharp)
    }

    @Test
    func resolvedName_eachSpelling() {
        let expected: [(GMNPitch.Name, Guido.Pitch.Name)] = [(.a, .a),
                                                             (.ais, .a),
                                                             (.b, .b),
                                                             (.c, .c),
                                                             (.cis, .c),
                                                             (.d, .d),
                                                             (.dis, .d),
                                                             (.do, .c),
                                                             (.e, .e),
                                                             (.empty, .empty),
                                                             (.f, .f),
                                                             (.fa, .f),
                                                             (.fis, .f),
                                                             (.g, .g),
                                                             (.gis, .g),
                                                             (.h, .b),
                                                             (.la, .a),
                                                             (.mi, .e),
                                                             (.re, .d),
                                                             (.si, .b),
                                                             (.sol, .g),
                                                             (.ti, .b)]

        for (name, resolved) in expected {
            #expect(Guido.Importer.Walker.resolvedName(name) == resolved)
        }
    }

    @Test
    func resolveNote_dots_areNotSticky() throws {
        let dots = try #require(GMNDuration.DotCount(uintValue: 1))
        let dotted = try makeGMNNote(duration: GMNDuration(numerator: 1, denominator: 4, dots: dots))
        var context = Guido.Importer.Context()

        let first = try Guido.Importer.Walker.resolveNote(dotted, &context)
        let second = try Guido.Importer.Walker.resolveNote(makeGMNNote(duration: nil), &context)

        #expect(first.duration.numberValue == Number(numerator: 3, denominator: 8))
        #expect(second.duration.numberValue == Number(numerator: 1, denominator: 4))
    }

    @Test
    func resolveNote_dotsOnly_augmentTheLastDuration() throws {
        let dots = try #require(GMNDuration.DotCount(uintValue: 2))
        var context = Guido.Importer.Context()

        _ = try Guido.Importer.Walker.resolveNote(makeGMNNote(duration: GMNDuration(numerator: 1, denominator: 2)), &context)

        let note = try Guido.Importer.Walker.resolveNote(makeGMNNote(duration: GMNDuration(dots: dots)), &context)

        #expect(note.duration.numberValue == Number(numerator: 7, denominator: 8))
    }

    @Test
    func resolveNote_durationIsSticky() throws {
        var context = Guido.Importer.Context()

        _ = try Guido.Importer.Walker.resolveNote(makeGMNNote(duration: GMNDuration(numerator: 1, denominator: 8)), &context)

        let note = try Guido.Importer.Walker.resolveNote(makeGMNNote(duration: nil), &context)

        #expect(note.duration.numberValue == Number(numerator: 1, denominator: 8))
    }

    @Test
    func resolveNote_milliseconds_throws() throws {
        let note = try makeGMNNote(duration: GMNDuration(milliseconds: 250))
        var context = Guido.Importer.Context()

        #expect(throws: Guido.Error.self) {
            try Guido.Importer.Walker.resolveNote(note, &context)
        }
    }

    @Test
    func resolveNote_octaveIsSticky() throws {
        let octave = try #require(GMNPitch.Octave(intValue: 2))
        let written = GMNNote(pitch: GMNPitch(name: .d, accidental: .omitted, octave: octave),
                              duration: nil)
        let unwritten = GMNNote(pitch: GMNPitch(name: .e, accidental: .omitted, octave: nil),
                                duration: nil)
        var context = Guido.Importer.Context()

        _ = try Guido.Importer.Walker.resolveNote(written, &context)

        let note = try Guido.Importer.Walker.resolveNote(unwritten, &context)

        #expect(note.pitch.octave == octave)
        #expect(context.lastOctave == octave)
    }

    @Test
    func resolveRestDuration_setsTheStickyDuration() throws {
        var context = Guido.Importer.Context()

        let duration = try Guido.Importer.Walker.resolveRestDuration(GMNRest(duration: GMNDuration(numerator: 1, denominator: 2)),
                                                                     &context)

        #expect(duration.numberValue == Number(numerator: 1, denominator: 2))
        #expect(context.lastDuration.numberValue == Number(numerator: 1, denominator: 2))
    }
}
