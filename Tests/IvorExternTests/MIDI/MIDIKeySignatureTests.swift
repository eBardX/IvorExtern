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
// Key signatures through MIDI: meta events in, key signature table entries
// out, and back.
//

struct MIDIKeySignatureTests {
}

// MARK: -

extension MIDIKeySignatureTests {
    @Test
    func export_customSignatureWritesNearestDiatonic() throws {
        let table = try keyTable([(0, customKeySignature([.fSharp, .gSharp]), nil)])

        #expect(try exportedKeyEvents(table) == ["0 1 0"])
    }

    @Test
    func export_emptyTableWritesNone() throws {
        #expect(try exportedKeyEvents(KeySignatureTable()).isEmpty)
    }

    @Test
    func export_minorAndAeolianSetMi() throws {
        let table = try keyTable([(0, keySignature(-3), "minor"),
                                  (1, keySignature(1), "aeolian"),
                                  (2, keySignature(2), "dorian")])

        #expect(try exportedKeyEvents(table) == ["0 -3 1", "1920 1 1", "3840 2 0"])
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

        #expect(keySummary(work.keySignatureTable) == ["1/2 2# major"])
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

        #expect(keySummary(work.keySignatureTable) == ["0 3b major"])
    }

    @Test
    func import_noKeys_givesEmptyTable() throws {
        let work = try MIDI.Importer().convert(MIDI.Exporter().convert(keyedKeyboardWork(KeySignatureTable())))

        #expect(work.keySignatureTable?.isEmpty == true)
    }

    @Test
    func roundTrip_keyChangesAndModes() throws {
        let table = try keyTable([(0, keySignature(-1), "minor"),
                                  (1, keySignature(4), "major"),
                                  (frac(3, 2), keySignature(-7), "minor")])
        let work = try MIDI.Importer().convert(MIDI.Exporter().convert(keyedKeyboardWork(table)))

        #expect(keySummary(work.keySignatureTable) == ["0 1b minor", "1 4# major", "3/2 7b minor"])
    }

    @Test
    func roundTrip_otherModesComeBackAsMajor() throws {
        let table = try keyTable([(0, keySignature(2), "dorian")])
        let work = try MIDI.Importer().convert(MIDI.Exporter().convert(keyedKeyboardWork(table)))

        #expect(keySummary(work.keySignatureTable) == ["0 2# major"])
    }

    // The conductor track's key signature events, at 480 ticks per quarter,
    // as `"<tick> <sf> <mi>"`.
    private func exportedKeyEvents(_ table: KeySignatureTable) throws -> [String] {
        let sequence = try MIDI.Exporter().convert(keyedKeyboardWork(table))

        return sequence.tracks[0].events.compactMap { event in
            guard case let .meta(eventTime, .keySignature(keySignature)) = event,
                  let bytes = keySignature.bytesValue
            else { return nil }

            return "\(eventTime.uintValue) \(Int8(bitPattern: bytes[0])) \(bytes[1])"
        }
    }
}
