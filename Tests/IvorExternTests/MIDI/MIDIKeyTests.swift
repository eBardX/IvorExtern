// © 2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import IvorMIDI
import IvorModel
import IvorSMF
import IvorTiming
import IvorTuning
import Testing
import XestiNumbers
import XestiTools

//
// Keys through MIDI: key signature meta events in, key table entries
// out, and back.
//

struct MIDIKeyTests {
}

// MARK: -

extension MIDIKeyTests {
    @Test
    func export_atonalWritesNoSharpsOrFlats() throws {
        let table = try keyTable([(0, .atonal)])

        #expect(try exportedKeyEvents(table) == ["0 0 0"])
    }

    @Test
    func export_customKeyWritesNearestDiatonic() throws {
        let table = try keyTable([(0, customKey([.fSharp, .gSharp]))])

        #expect(try exportedKeyEvents(table) == ["0 1 0"])
    }

    @Test
    func export_emptyTableWritesNone() throws {
        #expect(try exportedKeyEvents(KeyTable()).isEmpty)
    }

    @Test
    func export_onlyMinorSetsMi() throws {
        let table = try keyTable([(0, key(-3, .minor)),
                                  (1, key(1)),
                                  (2, key(2, .dorian))])

        #expect(try exportedKeyEvents(table) == ["0 -3 1", "1920 1 0", "3840 2 0"])
    }

    @Test
    func import_formatOne_usesFirstTrackWithKeys() throws {
        let conductor = SMFTrack(events: [.meta(SMFEventTime(960), .keySignature(.dMajor)),
                                          .meta(SMFEventTime(960), .endOfTrack)])
        let notes = SMFTrack(events: [.meta(.zero, .keySignature(.fSharpMinor)),
                                      .midi(.zero, .noteOn(MIDIChannel(1), MIDIData1Value(60), MIDIData1Value(100))),
                                      .midi(SMFEventTime(480), .noteOff(MIDIChannel(1), MIDIData1Value(60), MIDIData1Value(64))),
                                      .meta(SMFEventTime(480), .endOfTrack)])
        let work = try MIDI.Importer().convert(SMFSequence(format: .format1,
                                                           division: .metrical(SMFTickRate(480)),
                                                           tracks: [conductor, notes]))

        #expect(keySummary(work.keyTable) == ["1/2 D major"])
    }

    @Test
    func import_keysOnlyInANoteTrack() throws {
        let conductor = SMFTrack(events: [.meta(.zero, .endOfTrack)])
        let notes = SMFTrack(events: [.meta(.zero, .keySignature(.eFlatMajor)),
                                      .midi(.zero, .noteOn(MIDIChannel(1), MIDIData1Value(60), MIDIData1Value(100))),
                                      .midi(SMFEventTime(480), .noteOff(MIDIChannel(1), MIDIData1Value(60), MIDIData1Value(64))),
                                      .meta(SMFEventTime(480), .endOfTrack)])
        let work = try MIDI.Importer().convert(SMFSequence(format: .format1,
                                                           division: .metrical(SMFTickRate(480)),
                                                           tracks: [conductor, notes]))

        #expect(keySummary(work.keyTable) == ["0 Eb major"])
    }

    @Test
    func import_noKeys_givesEmptyTable() throws {
        let work = try MIDI.Importer().convert(MIDI.Exporter().convert(keyedKeyboardWork(KeyTable())))

        #expect(work.keyTable?.isEmpty == true)
    }

    @Test
    func roundTrip_keyChangesAndModes() throws {
        let table = try keyTable([(0, key(-1, .minor)),
                                  (1, key(4, .major)),
                                  (frac(3, 2), key(-7, .minor))])
        let work = try MIDI.Importer().convert(MIDI.Exporter().convert(keyedKeyboardWork(table)))

        #expect(keySummary(work.keyTable) == ["0 D minor", "1 E major", "3/2 Ab minor"])
    }

    @Test
    func roundTrip_otherModesAndNoModeComeBackAsMajor() throws {
        // MIDI keys are taken at face value: `mi` 0 is major.
        let table = try keyTable([(0, key(2, .dorian)),
                                  (1, key(-1)),
                                  (frac(3, 2), .atonal)])
        let work = try MIDI.Importer().convert(MIDI.Exporter().convert(keyedKeyboardWork(table)))

        #expect(keySummary(work.keyTable) == ["0 D major", "1 F major", "3/2 C major"])
    }

    // The conductor track's key signature events, at 480 ticks per quarter,
    // as `"<tick> <sf> <mi>"`.
    private func exportedKeyEvents(_ table: KeyTable) throws -> [String] {
        let sequence = try MIDI.Exporter().convert(keyedKeyboardWork(table))

        return sequence.tracks[0].events.compactMap { event in
            guard case let .meta(eventTime, .keySignature(keySignature)) = event,
                  let bytes = keySignature.bytesValue
            else { return nil }

            return "\(eventTime.uintValue) \(Int8(bitPattern: bytes[0])) \(bytes[1])"
        }
    }
}
