// © 2025–2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import IvorGMN
import IvorModel
import IvorTiming
import IvorTuning
import Testing
import XestiNumbers
import XestiTools

// swiftlint:disable file_length

struct GuidoImporterWalkerTests {
}

// MARK: -

extension GuidoImporterWalkerTests {
    @Test
    func walk_articulationTag_attachesFlagToNextNote() throws {
        let octave = try #require(GMNPitch.Octave(intValue: 1))
        let note = GMNNote(pitch: GMNPitch(name: .c, accidental: .omitted, octave: octave),
                           duration: GMNDuration(numerator: 1, denominator: 4))
        let articulation = try #require(GMNArticulation(kind: .accent))
        let walker = Guido.Importer.Walker(variables: [:])
        let voice = Guido.Voice(symbols: [.tag(.articulation(articulation)), .note(note)])

        let context = try walker.walk(voice)

        #expect(context.noteTable.contains { hasFlag($0.extras, .accent) })
    }

    @Test
    func walk_articulationTag_bowKnownTypes_becomeBowFlags() throws {
        let types: [(String, Extra)] = [("DOWN", .downBow),
                                        ("up", .upBow)]

        for (type, extra) in types {
            let bow = try #require(GMNArticulation(kind: .bow, type: type))
            let context = try walkGMN([.tag(.articulation(bow)), .note(makeGMNNote())])

            #expect(hasFlag(context.noteTable.map(\.extras).first.flatMap(\.self), extra))
        }
    }

    @Test
    func walk_articulationTag_bowUnknownType_becomesArticulationExtra() throws {
        let bow = try #require(GMNArticulation(kind: .bow, type: "sideways"))
        let context = try walkGMN([.tag(.articulation(bow)), .note(makeGMNNote())])

        #expect(stringValue(context.noteTable.map(\.extras).first.flatMap(\.self), .articulation) == "bow")
    }

    @Test
    func walk_articulationTag_kinds_becomeTheirFlags() throws {
        let kinds: [(GMNArticulation.Kind, Extra)] = [(.fermata, .fermata),
                                                      (.harmonic, .harmonic),
                                                      (.marcato, .marcato),
                                                      (.staccato, .staccato),
                                                      (.tenuto, .tenuto)]

        for (kind, extra) in kinds {
            let articulation = try #require(GMNArticulation(kind: kind, body: [.note(makeGMNNote())]))
            let context = try walkGMN([.tag(.articulation(articulation))])

            #expect(hasFlag(context.noteTable.map(\.extras).first.flatMap(\.self), extra))
        }
    }

    @Test
    func walk_beamTag_walksNotesInBody() throws {
        let octave = try #require(GMNPitch.Octave(intValue: 1))
        let note = GMNNote(pitch: GMNPitch(name: .c, accidental: .omitted, octave: octave),
                           duration: GMNDuration(numerator: 1, denominator: 4))
        let beam = try #require(GMNBeam(kind: .normal, body: [.note(note)]))
        let walker = Guido.Importer.Walker(variables: [:])
        let voice = Guido.Voice(symbols: [.tag(.beam(beam))])

        let context = try walker.walk(voice)

        var count = 0

        for _ in context.noteTable {
            count += 1
        }

        #expect(count == 1)
    }

    @Test
    func walk_breathMarkTag_attachesFlagAndWalksBody() throws {
        let breathMark = try GMNBreathMark(body: [.note(makeGMNNote())])
        let context = try walkGMN([.tag(.breathMark(breathMark))])

        #expect(hasFlag(context.noteTable.map(\.extras).first.flatMap(\.self), .breathMark))
    }

    @Test
    func walk_chord_insertsMembersAndAdvancesByMaxDuration() throws {
        let octave = try #require(GMNPitch.Octave(intValue: 1))
        let note1 = GMNNote(pitch: GMNPitch(name: .c, accidental: .omitted, octave: octave),
                            duration: GMNDuration(numerator: 1, denominator: 2))
        let note2 = GMNNote(pitch: GMNPitch(name: .e, accidental: .omitted, octave: octave),
                            duration: GMNDuration(numerator: 1, denominator: 4))
        let segment1 = try #require(GMNChord.Segment(symbols: [.note(note1)]))
        let segment2 = try #require(GMNChord.Segment(symbols: [.note(note2)]))
        let chord = try #require(GMNChord(segments: [segment1, segment2]))
        let walker = Guido.Importer.Walker(variables: [:])
        let voice = Guido.Voice(symbols: [.chord(chord)])

        let context = try walker.walk(voice)

        var count = 0

        for _ in context.noteTable {
            count += 1
        }

        #expect(count == 2)
        #expect(context.currentBeatTime == BeatTime(2))
    }

    @Test
    func walk_chord_restSegment_stillSetsTheStickyDuration() throws {
        let rest = GMNRest(duration: GMNDuration(numerator: 1, denominator: 2))
        let restSegment = try #require(GMNChord.Segment(symbols: [.rest(rest)]))
        let noteSegment = try #require(GMNChord.Segment(symbols: [.note(makeGMNNote(duration: nil))]))
        let chord = try #require(GMNChord(segments: [restSegment, noteSegment]))
        let context = try walkGMN([.chord(chord)])

        #expect(context.noteTable.map(\.duration) == [BeatDuration(2)])
    }

    @Test
    func walk_chord_tagInASegment_isSkipped() throws {
        let intensity = GMNIntensity(type: "ff")
        let segment = try #require(GMNChord.Segment(symbols: [.tag(.intensity(intensity)), .note(makeGMNNote())]))
        let chord = try #require(GMNChord(segments: [segment]))
        let context = try walkGMN([.chord(chord)])

        #expect(context.noteTable.map(\.attack) == [.zero])
        #expect(context.dynamicEvents.isEmpty)
    }

    @Test
    func walk_circularVariableReference_throws() throws {
        let name = try #require(GMNVariable.Name(stringValue: "x"))
        let variable = GMNVariable(name: name, value: .string("$x"))
        let walker = Guido.Importer.Walker(variables: [name: variable])
        let voice = Guido.Voice(symbols: [.variable(name)])

        #expect(throws: (any Error).self) {
            try walker.walk(voice)
        }
    }

    @Test
    func walk_crescBeginEnd_pairsByIdent() throws {
        let octave = try #require(GMNPitch.Octave(intValue: 1))
        let note = GMNNote(pitch: GMNPitch(name: .c, accidental: .omitted, octave: octave),
                           duration: GMNDuration(numerator: 1, denominator: 4))
        let ident = try #require(GMNTag.Ident(uintValue: 1))
        let begin = try #require(GMNDynamicRamp(ident: ident, direction: .crescendo, span: .begin))
        let end = try #require(GMNDynamicRamp(ident: ident, direction: .crescendo, span: .end))
        let walker = Guido.Importer.Walker(variables: [:])
        let voice = Guido.Voice(symbols: [.tag(.dynamicRamp(begin)), .note(note), .tag(.dynamicRamp(end))])

        let context = try walker.walk(voice)

        #expect(context.dynamicEvents.count == 2)
        #expect(context.dynamicEvents.allSatisfy { $0.kind == .rampBoundary })
        #expect(context.dynamicEvents.first?.beatTime == .zero)
        #expect(context.dynamicEvents.first?.dynamic == .mp)
        #expect(context.dynamicEvents.last?.beatTime == BeatTime(1))
        #expect(context.dynamicEvents.last?.dynamic == .mf)
    }

    @Test
    func walk_crescendoWhole_rampsFromStartingLevel() throws {
        let octave = try #require(GMNPitch.Octave(intValue: 1))
        let note = GMNNote(pitch: GMNPitch(name: .c, accidental: .omitted, octave: octave),
                           duration: GMNDuration(numerator: 1, denominator: 4))
        let intensity = GMNIntensity(type: "p")
        let ramp = try #require(GMNDynamicRamp(direction: .crescendo, span: .whole, body: [.note(note)]))
        let walker = Guido.Importer.Walker(variables: [:])
        let voice = Guido.Voice(symbols: [.tag(.intensity(intensity)), .tag(.dynamicRamp(ramp))])

        let context = try walker.walk(voice)

        #expect(context.dynamicEvents.count == 3)
        #expect(context.dynamicEvents[0].dynamic == .p)
        #expect(context.dynamicEvents[0].kind == .step)
        #expect(context.dynamicEvents[1].beatTime == .zero)
        #expect(context.dynamicEvents[1].dynamic == .p)
        #expect(context.dynamicEvents[1].kind == .rampBoundary)
        #expect(context.dynamicEvents[2].beatTime == BeatTime(1))
        #expect(context.dynamicEvents[2].dynamic == .mp)
        #expect(context.dynamicEvents[2].kind == .rampBoundary)
    }

    @Test
    func walk_cueTag_staysInertAndBreaksATie() throws {
        let tie = try #require(GMNTie(span: .end))
        let cue = try GMNCue(body: [.note(makeGMNNote())])
        let context = try walkGMN([.note(makeGMNNote()), .tag(.tie(tie)), .tag(.cue(cue)), .note(makeGMNNote())])

        #expect(context.noteTable.map(\.attack) == [.zero, BeatTime(1)])
    }

    @Test
    func walk_dottedNote_appliesDots() throws {
        let octave = try #require(GMNPitch.Octave(intValue: 1))
        let duration = GMNDuration(numerator: 1, denominator: 4, dots: GMNDuration.DotCount(uintValue: 1))
        let note = GMNNote(pitch: GMNPitch(name: .c, accidental: .omitted, octave: octave), duration: duration)
        let walker = Guido.Importer.Walker(variables: [:])
        let voice = Guido.Voice(symbols: [.note(note)])

        let context = try walker.walk(voice)

        #expect(context.currentBeatTime == BeatTime(1.5))
    }

    @Test
    func walk_emptyVoice_returnsEmptyContext() throws {
        let walker = Guido.Importer.Walker(variables: [:])
        let voice = Guido.Voice(symbols: [])

        let context = try walker.walk(voice)

        #expect(context.noteTable.isEmpty)
        #expect(context.tempoEvents.isEmpty)
        #expect(context.currentBeatTime == .zero)
    }

    @Test
    func walk_fingeringTag_attachesTextAndWalksBody() throws {
        let fingering = try GMNFingering(text: "3", body: [.note(makeGMNNote())])
        let context = try walkGMN([.tag(.fingering(fingering))])

        #expect(stringValue(context.noteTable.map(\.extras).first.flatMap(\.self), .fingering) == "3")
    }

    @Test
    func walk_graceTag_staysInertAndBreaksATie() throws {
        let tie = try #require(GMNTie(span: .end))
        let grace = try GMNGrace(body: [.note(makeGMNNote())])
        let context = try walkGMN([.note(makeGMNNote()), .tag(.tie(tie)), .tag(.grace(grace)), .note(makeGMNNote())])

        #expect(context.noteTable.map(\.attack) == [.zero, BeatTime(1)])
    }

    @Test
    func walk_instrumentTag_recordsInstrumentEvent() throws {
        let instrument = GMNInstrument(name: "Piano")
        let walker = Guido.Importer.Walker(variables: [:])
        let voice = Guido.Voice(symbols: [.tag(.instrument(instrument))])

        let context = try walker.walk(voice)

        #expect(context.instrumentEvents.count == 1)
        #expect(context.instrumentEvents.first?.beatTime == .zero)
        #expect(context.instrumentEvents.first?.instrument == Instrument("Piano"))
    }

    @Test
    func walk_intensityTag_recordsStepDynamicEvent() throws {
        let intensity = GMNIntensity(type: "ff")
        let walker = Guido.Importer.Walker(variables: [:])
        let voice = Guido.Voice(symbols: [.tag(.intensity(intensity))])

        let context = try walker.walk(voice)

        #expect(context.dynamicEvents.count == 1)
        #expect(context.dynamicEvents.first?.beatTime == .zero)
        #expect(context.dynamicEvents.first?.dynamic == .ff)
        #expect(context.dynamicEvents.first?.kind == .step)
    }

    @Test
    func walk_intensityTag_unrecognizedType_recordsMarkedStepAtPreviousLevel() throws {
        let intensity = GMNIntensity(type: "cresc.")
        let walker = Guido.Importer.Walker(variables: [:])
        let voice = Guido.Voice(symbols: [.tag(.intensity(intensity))])

        let context = try walker.walk(voice)

        #expect(context.dynamicEvents.count == 1)
        #expect(context.dynamicEvents.first?.beatTime == .zero)
        #expect(context.dynamicEvents.first?.dynamic == .mp)
        #expect(context.dynamicEvents.first?.kind == .step)
        #expect(context.dynamicEvents.first?.mark == "cresc.")
    }

    @Test
    func walk_millisecondDuration_throws() {
        let rest = GMNRest(duration: GMNDuration(milliseconds: 500))
        let walker = Guido.Importer.Walker(variables: [:])
        let voice = Guido.Voice(symbols: [.rest(rest)])

        #expect(throws: (any Error).self) {
            try walker.walk(voice)
        }
    }

    @Test
    func walk_note_emptyPitch_advancesWithoutInsertingNote() throws {
        let context = try walkGMN([.note(makeGMNNote(name: .empty))])

        #expect(context.noteTable.map(\.attack).isEmpty)
        #expect(context.currentBeatTime == BeatTime(1))
    }

    @Test
    func walk_note_insertsNoteAndAdvances() throws {
        let octave = try #require(GMNPitch.Octave(intValue: 1))
        let note = GMNNote(pitch: GMNPitch(name: .c, accidental: .omitted, octave: octave),
                           duration: GMNDuration(numerator: 1, denominator: 4))
        let walker = Guido.Importer.Walker(variables: [:])
        let voice = Guido.Voice(symbols: [.note(note)])

        let context = try walker.walk(voice)

        var count = 0

        for note in context.noteTable {
            count += 1

            #expect(note.attack == .zero)
            #expect(note.duration == BeatDuration(1))
        }

        #expect(count == 1)
        #expect(context.currentBeatTime == BeatTime(1))
    }

    @Test
    func walk_note_resolvesAccidentals() throws {
        let accidentals: [(GMNPitch.Accidental, Pitch.Accidental)] = [(.doubleFlat, .doubleFlat),
                                                                      (.doubleSharp, .doubleSharp),
                                                                      (.flat, .flat),
                                                                      (.impliedSharp, .sharp),
                                                                      (.omitted, .natural),
                                                                      (.sharp, .sharp)]

        for (accidental, expected) in accidentals {
            let context = try walkGMN([.note(makeGMNNote(accidental: accidental))])

            #expect(context.noteTable.map(\.startPitch.pitchClass.accidental) == [expected])
        }
    }

    @Test
    func walk_note_resolvesNames() throws {
        let names: [(GMNPitch.Name, Pitch.Letter)] = [(.a, .a),
                                                      (.ais, .a),
                                                      (.b, .b),
                                                      (.c, .c),
                                                      (.cis, .c),
                                                      (.d, .d),
                                                      (.dis, .d),
                                                      (.do, .c),
                                                      (.e, .e),
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

        for (name, letter) in names {
            let context = try walkGMN([.note(makeGMNNote(name: name))])

            #expect(context.noteTable.map(\.startPitch.pitchClass.letter) == [letter])
        }
    }

    @Test
    func walk_ornamentTag_kinds_becomeTheirFlags() throws {
        let kinds: [(GMNOrnament.Kind, Extra)] = [(.mordent, .mordent),
                                                  (.trill, .trill),
                                                  (.turn, .turn)]

        for (kind, extra) in kinds {
            let ornament = try #require(GMNOrnament(kind: kind, body: [.note(makeGMNNote())]))
            let context = try walkGMN([.tag(.ornament(ornament))])

            #expect(hasFlag(context.noteTable.map(\.extras).first.flatMap(\.self), extra))
        }
    }

    @Test
    func walk_pedalTags_recordSustainAtTheCurrentBeat() throws {
        let octave = try #require(GMNPitch.Octave(intValue: 1))
        let note = GMNNote(pitch: GMNPitch(name: .c, accidental: .omitted, octave: octave),
                           duration: GMNDuration(numerator: 1, denominator: 4))
        let walker = Guido.Importer.Walker(variables: [:])
        let voice = Guido.Voice(symbols: [.tag(.pedal(GMNPedal(kind: .on))),
                                          .note(note),
                                          .tag(.pedal(GMNPedal(kind: .off)))])

        let context = try walker.walk(voice)

        #expect(context.sustainTable.map(\.time) == [0, 1])
        #expect(context.sustainTable.map(\.level) == [.down, .up])
    }

    @Test
    func walk_rest_advancesWithoutInsertingNote() throws {
        let rest = GMNRest(duration: GMNDuration(numerator: 1, denominator: 4))
        let walker = Guido.Importer.Walker(variables: [:])
        let voice = Guido.Voice(symbols: [.rest(rest)])

        let context = try walker.walk(voice)

        #expect(context.noteTable.isEmpty)
        #expect(context.currentBeatTime == BeatTime(1))
    }

    @Test
    func walk_slurBeginEnd_attachesStartAndEndFlags() throws {
        let octave = try #require(GMNPitch.Octave(intValue: 1))
        let note1 = GMNNote(pitch: GMNPitch(name: .c, accidental: .omitted, octave: octave),
                            duration: GMNDuration(numerator: 1, denominator: 4))
        let note2 = GMNNote(pitch: GMNPitch(name: .d, accidental: .omitted, octave: octave),
                            duration: GMNDuration(numerator: 1, denominator: 4))
        let ident = try #require(GMNTag.Ident(uintValue: 1))
        let begin = try #require(GMNSlur(ident: ident, span: .begin))
        let end = try #require(GMNSlur(ident: ident, span: .end))
        let walker = Guido.Importer.Walker(variables: [:])
        let voice = Guido.Voice(symbols: [.tag(.slur(begin)), .note(note1), .note(note2), .tag(.slur(end))])

        let context = try walker.walk(voice)

        var flags: [(start: String?, end: String?)] = []

        for note in context.noteTable {
            flags.append((stringValue(note.extras, .slurStart), stringValue(note.extras, .slurEnd)))
        }

        #expect(flags.count == 2)
        #expect(flags[0].start == "1")
        #expect(flags[1].end == "1")
    }

    @Test
    func walk_tablature_throwsUnsupportedEvent() throws {
        let tablature = try #require(GMNTablature(tabString: 1, fret: "3", duration: nil))
        let walker = Guido.Importer.Walker(variables: [:])
        let voice = Guido.Voice(symbols: [.tablature(tablature)])

        #expect(throws: (any Error).self) {
            try walker.walk(voice)
        }
    }

    @Test
    func walk_tempoTag_recordsTempoEvent() throws {
        let unit = try #require(GMNTempo.Metronome.BeatUnit(1, 4))
        let metronome = GMNTempo.Metronome.rate(unit: unit, beats: 120)
        let tempo = GMNTempo(tempo: "Allegro", metronome: metronome)
        let walker = Guido.Importer.Walker(variables: [:])
        let voice = Guido.Voice(symbols: [.tag(.tempo(tempo))])

        let context = try walker.walk(voice)

        #expect(context.tempoEvents.count == 1)
        #expect(context.tempoEvents.first?.beatTime == .zero)
        #expect(context.tempoEvents.first?.tempo == Tempo(uintValue: 120))
    }

    @Test
    func walk_tie_matchingPitches_coalescesDurations() throws {
        let octave = try #require(GMNPitch.Octave(intValue: 1))
        let pitch = GMNPitch(name: .c, accidental: .omitted, octave: octave)
        let note1 = GMNNote(pitch: pitch, duration: GMNDuration(numerator: 1, denominator: 4))
        let note2 = GMNNote(pitch: pitch, duration: GMNDuration(numerator: 1, denominator: 4))
        let tie = try #require(GMNTie(span: .end))
        let walker = Guido.Importer.Walker(variables: [:])
        let voice = Guido.Voice(symbols: [.note(note1), .tag(.tie(tie)), .note(note2)])

        let context = try walker.walk(voice)

        var count = 0

        for note in context.noteTable {
            count += 1

            #expect(note.attack == .zero)
            #expect(note.duration == BeatDuration(2))
        }

        #expect(count == 1)
    }

    @Test
    func walk_tie_mismatchedPitches_doesNotCoalesce() throws {
        let octave = try #require(GMNPitch.Octave(intValue: 1))
        let note1 = GMNNote(pitch: GMNPitch(name: .c, accidental: .omitted, octave: octave),
                            duration: GMNDuration(numerator: 1, denominator: 4))
        let note2 = GMNNote(pitch: GMNPitch(name: .d, accidental: .omitted, octave: octave),
                            duration: GMNDuration(numerator: 1, denominator: 4))
        let tie = try #require(GMNTie(span: .end))
        let walker = Guido.Importer.Walker(variables: [:])
        let voice = Guido.Voice(symbols: [.note(note1), .tag(.tie(tie)), .note(note2)])

        let context = try walker.walk(voice)

        var count = 0

        for _ in context.noteTable {
            count += 1
        }

        #expect(count == 2)
    }

    @Test
    func walk_variableReference_expandsSymbols() throws {
        let name = try #require(GMNVariable.Name(stringValue: "x"))
        let variable = GMNVariable(name: name, value: .string("c d e"))
        let walker = Guido.Importer.Walker(variables: [name: variable])
        let voice = Guido.Voice(symbols: [.variable(name)])

        let context = try walker.walk(voice)

        var count = 0

        for _ in context.noteTable {
            count += 1
        }

        #expect(count == 3)
        #expect(context.currentBeatTime == BeatTime(3))
    }

    @Test
    func walk_variableReference_numericDeclarationsParseAlongsideIt() throws {
        let name = try #require(GMNVariable.Name(stringValue: "x"))
        let floatingName = try #require(GMNVariable.Name(stringValue: "y"))
        let integerName = try #require(GMNVariable.Name(stringValue: "z"))
        let walker = Guido.Importer.Walker(variables: [floatingName: GMNVariable(name: floatingName, value: .floating(1.5)),
                                                       integerName: GMNVariable(name: integerName, value: .integer(5)),
                                                       name: GMNVariable(name: name, value: .string("c d"))])

        let context = try walker.walk(Guido.Voice(symbols: [.variable(name)]))

        #expect(context.noteTable.map(\.attack) == [.zero, BeatTime(1)])
    }

    @Test
    func walk_wholeTagSlur_attachesFlagsToFirstAndLastBodyNote() throws {
        let octave = try #require(GMNPitch.Octave(intValue: 1))
        let note1 = GMNNote(pitch: GMNPitch(name: .c, accidental: .omitted, octave: octave),
                            duration: GMNDuration(numerator: 1, denominator: 4))
        let note2 = GMNNote(pitch: GMNPitch(name: .d, accidental: .omitted, octave: octave),
                            duration: GMNDuration(numerator: 1, denominator: 4))
        let slur = try #require(GMNSlur(span: .whole, body: [.note(note1), .note(note2)]))
        let walker = Guido.Importer.Walker(variables: [:])
        let voice = Guido.Voice(symbols: [.tag(.slur(slur))])

        let context = try walker.walk(voice)

        var flags: [(start: Bool, end: Bool)] = []

        for note in context.noteTable {
            flags.append((hasFlag(note.extras, .slurStart), hasFlag(note.extras, .slurEnd)))
        }

        #expect(flags.count == 2)
        #expect(flags[0].start)
        #expect(!flags[0].end)
        #expect(!flags[1].start)
        #expect(flags[1].end)
    }
}

// swiftlint:enable file_length
