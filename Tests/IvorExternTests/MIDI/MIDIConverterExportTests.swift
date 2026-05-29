// © 2025–2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import IvorMIDI
import IvorModel
import IvorTiming
import IvorTuning
import Testing
import XestiNumbers
import XestiTools

struct MIDIConverterExportTests {
}

// MARK: -

extension MIDIConverterExportTests {

    @Test
    func convert_keyboardBeat_empty() throws {
        let work = Work(name: "Test",
                        content: .keyboardBeat([],
                                               TempoMap()))
        let sequence = try MIDI.Converter().convert(work)

        #expect(sequence.format == .format1)
        #expect(sequence.tracks.count == 1)
    }

    @Test
    func convert_keyboardBeat_singleNote() throws {
        var table = NoteTable<BeatTime, NoteNumber>()

        table.insert(attack: BeatTime(0),
                     duration: BeatDuration(1),
                     pitch: NoteNumber(60))

        let part = Part(name: "Piano",
                        noteTable: table)
        let work = Work(name: "Test",
                        content: .keyboardBeat([part],
                                               TempoMap()))
        let sequence = try MIDI.Converter().convert(work)

        #expect(sequence.tracks.count == 2)

        let partTrack = sequence.tracks[1]
        let midiEvents = partTrack.events.filter {
            if case .midi = $0 {
                return true
            }

            return false
        }

        #expect(midiEvents.count == 2)

        if case let .midi(t0, msg0) = midiEvents[0] {
            #expect(t0.uintValue == 0)
            if case let .noteOn(_, note, vel) = msg0 {
                #expect(note.uintValue == 60)
                #expect(vel.uintValue == 64)
            }
        }

        if case let .midi(t1, _) = midiEvents[1] {
            #expect(t1.uintValue == 480)
        }
    }

    @Test
    func convert_keyboardBeat_twoParts() throws {
        var table1 = NoteTable<BeatTime, NoteNumber>()

        table1.insert(attack: BeatTime(0),
                      duration: BeatDuration(1),
                      pitch: NoteNumber(60))

        var table2 = NoteTable<BeatTime, NoteNumber>()

        table2.insert(attack: BeatTime(0),
                      duration: BeatDuration(2),
                      pitch: NoteNumber(64))

        let parts = [Part(name: "P1", noteTable: table1),
                     Part(name: "P2", noteTable: table2)]
        let work = Work(name: "TwoParts",
                        content: .keyboardBeat(parts,
                                               TempoMap()))
        let sequence = try MIDI.Converter().convert(work)

        #expect(sequence.tracks.count == 3)
    }

    @Test
    func convert_keyboardBeat_tempoMap() throws {
        var tempoMap = TempoMap()

        tempoMap.insert(beatTime: BeatTime(0),
                        tempo: Tempo(120))
        tempoMap.insert(beatTime: BeatTime(4),
                        tempo: Tempo(120))

        let work = Work(name: "Tempo",
                        content: .keyboardBeat([],
                                               tempoMap))
        let sequence = try MIDI.Converter().convert(work)

        let track0 = sequence.tracks[0]
        let tempoEvents = track0.events.filter {
            if case let .meta(_, msg) = $0,
               case .tempo = msg { return true }
            return false
        }

        #expect(!tempoEvents.isEmpty)
    }

    @Test
    func convert_track0_hasTimeSignature() throws {
        let work = Work(name: "",
                        content: .keyboardBeat([],
                                               TempoMap()))
        let sequence = try MIDI.Converter().convert(work)
        let track0 = sequence.tracks[0]
        let tsigEvents = track0.events.filter {
            if case let .meta(_, msg) = $0,
               case .timeSignature = msg { return true }
            return false
        }

        #expect(tsigEvents.count == 1)
    }

    @Test
    func convert_unsupportedContent_throws() {
        let work = Work(name: "Wall",
                        content: .keyboardWall([]))

        #expect(throws: (any Error).self) {
            try MIDI.Converter().convert(work)
        }
    }
}
