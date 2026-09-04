// © 2025–2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import IvorGuido
import IvorModel
import IvorTiming
import Testing
import XestiNumbers
import XestiTools

struct GuidoImporterWalkerTests {
}

// MARK: -

extension GuidoImporterWalkerTests {
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

        context.noteTable.forEach { _, _, _, _, _, _ in count += 1 }

        #expect(count == 2)
        #expect(context.currentBeatTime == BeatTime(2))
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
    func walk_intensityTag_unrecognizedType_recordsNothing() throws {
        let intensity = GMNIntensity(type: "cresc.")
        let walker = Guido.Importer.Walker(variables: [:])
        let voice = Guido.Voice(symbols: [.tag(.intensity(intensity))])

        let context = try walker.walk(voice)

        #expect(context.dynamicEvents.isEmpty)
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
    func walk_note_insertsNoteAndAdvances() throws {
        let octave = try #require(GMNPitch.Octave(intValue: 1))
        let note = GMNNote(pitch: GMNPitch(name: .c, accidental: .omitted, octave: octave),
                           duration: GMNDuration(numerator: 1, denominator: 4))
        let walker = Guido.Importer.Walker(variables: [:])
        let voice = Guido.Voice(symbols: [.note(note)])

        let context = try walker.walk(voice)

        var count = 0

        context.noteTable.forEach { _, attack, duration, _, _, _ in
            count += 1

            #expect(attack == .zero)
            #expect(duration == BeatDuration(1))
        }

        #expect(count == 1)
        #expect(context.currentBeatTime == BeatTime(1))
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

        context.noteTable.forEach { _, attack, duration, _, _, _ in
            count += 1

            #expect(attack == .zero)
            #expect(duration == BeatDuration(2))
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

        context.noteTable.forEach { _, _, _, _, _, _ in count += 1 }

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

        context.noteTable.forEach { _, _, _, _, _, _ in count += 1 }

        #expect(count == 3)
        #expect(context.currentBeatTime == BeatTime(3))
    }
}
