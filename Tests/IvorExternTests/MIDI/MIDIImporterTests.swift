// © 2025–2026 John Gary Pusey (see LICENSE.md)

import Foundation
@testable import IvorExtern
import IvorMIDI
import IvorModel
import IvorTiming
import Testing
import XestiTools

struct MIDIImporterTests {
}

// MARK: -

extension MIDIImporterTests {
    @Test
    func convert_namedTracksSharingAChannel_produceOnePartPerTrack() throws {
        // The common single-instrument convention: every part shares one
        // channel, and only the track boundary (plus each track's own
        // `sequenceTrackName`) distinguishes them.
        let rightHandName = try #require(SMFText(stringValue: "Right Hand"))
        let leftHandName = try #require(SMFText(stringValue: "Left Hand"))
        let channel = MIDIChannel(1)
        let key = MIDIData1Value(0x3c)
        let noteOn = MIDIChannelMessage.noteOn(channel, key, MIDIData1Value(100))
        let noteOff = MIDIChannelMessage.noteOff(channel, key, MIDIData1Value(64))
        let rightHandTrack = SMFTrack(events: [.meta(.zero, .sequenceTrackName(rightHandName)),
                                               .midi(.zero, noteOn),
                                               .midi(SMFEventTime(96), noteOff),
                                               .meta(SMFEventTime(96), .endOfTrack)])
        let leftHandTrack = SMFTrack(events: [.meta(.zero, .sequenceTrackName(leftHandName)),
                                              .midi(.zero, noteOn),
                                              .midi(SMFEventTime(96), noteOff),
                                              .meta(SMFEventTime(96), .endOfTrack)])
        let sequence = SMFSequence(format: .format1,
                                   division: .metrical(SMFTickRate(480)),
                                   tracks: [rightHandTrack, leftHandTrack])
        let work = try MIDI.Importer().convert(sequence)

        guard case let .keyboardBeat(parts, _) = work.content
        else { Issue.record("Expected keyboardBeat content"); return }

        #expect(parts.map(\.name) == ["Right Hand", "Left Hand"])
    }

    @Test
    func convert_namedTrackWithMultipleChannels_disambiguatesPartsByChannel() throws {
        // Each track packs two channels into itself, so — unlike the
        // single-channel-per-track case above — every part it produces
        // needs the channel suffix to stay distinct from its
        // trackmate's, exactly as `MusicXML.Importer._makePartName`
        // appends ", Voice N" only when a part has more than one voice.
        let rightHandName = try #require(SMFText(stringValue: "Right Hand"))
        let leftHandName = try #require(SMFText(stringValue: "Left Hand"))
        let key = MIDIData1Value(0x3c)
        let channel1 = MIDIChannel(1)
        let channel2 = MIDIChannel(2)
        let channel3 = MIDIChannel(3)
        let channel4 = MIDIChannel(4)
        let rightHandTrack = SMFTrack(events: [.meta(.zero, .sequenceTrackName(rightHandName)),
                                               .midi(.zero, .noteOn(channel1, key, MIDIData1Value(100))),
                                               .midi(SMFEventTime(96), .noteOff(channel1, key, MIDIData1Value(64))),
                                               .midi(.zero, .noteOn(channel2, key, MIDIData1Value(100))),
                                               .midi(SMFEventTime(96), .noteOff(channel2, key, MIDIData1Value(64))),
                                               .meta(SMFEventTime(96), .endOfTrack)])
        let leftHandTrack = SMFTrack(events: [.meta(.zero, .sequenceTrackName(leftHandName)),
                                              .midi(.zero, .noteOn(channel3, key, MIDIData1Value(100))),
                                              .midi(SMFEventTime(96), .noteOff(channel3, key, MIDIData1Value(64))),
                                              .midi(.zero, .noteOn(channel4, key, MIDIData1Value(100))),
                                              .midi(SMFEventTime(96), .noteOff(channel4, key, MIDIData1Value(64))),
                                              .meta(SMFEventTime(96), .endOfTrack)])
        let sequence = SMFSequence(format: .format1,
                                   division: .metrical(SMFTickRate(480)),
                                   tracks: [rightHandTrack, leftHandTrack])
        let work = try MIDI.Importer().convert(sequence)

        guard case let .keyboardBeat(parts, _) = work.content
        else { Issue.record("Expected keyboardBeat content"); return }

        #expect(parts.map(\.name) == ["Right Hand, Channel 1",
                                      "Right Hand, Channel 2",
                                      "Left Hand, Channel 3",
                                      "Left Hand, Channel 4"])
    }

    @Test
    func convert_programChangeEvent_populatesInstrumentMap() throws {
        let programChange = MIDIChannelMessage.programChange(MIDIChannel(1), MIDIData1Value(40))
        let track = SMFTrack(events: [.midi(.zero, programChange),
                                      .meta(.zero, .endOfTrack)])
        let sequence = SMFSequence(format: .format1,
                                   division: .metrical(SMFTickRate(480)),
                                   tracks: [track])
        let work = try MIDI.Importer().convert(sequence)

        guard case let .keyboardBeat(parts, _) = work.content
        else { Issue.record("Expected keyboardBeat content"); return }

        #expect(parts.first?.instrumentMap[.zero] == Instrument("Violin"))
    }

    @Test
    func convert_tempoMetaEvent_populatesTempoMap() throws {
        let track = SMFTrack(events: [.meta(.zero, .tempo(SMFTempo(500_000))),
                                      .meta(.zero, .endOfTrack)])
        let sequence = SMFSequence(format: .format1,
                                   division: .metrical(SMFTickRate(480)),
                                   tracks: [track])
        let work = try MIDI.Importer().convert(sequence)

        guard case let .keyboardBeat(_, tempoMap) = work.content
        else { Issue.record("Expected keyboardBeat content"); return }

        #expect(!tempoMap.isEmpty)
    }

    @Test
    func convert_unnamedTrack_partNamedByChannel() throws {
        let channel = MIDIChannel(1)
        let key = MIDIData1Value(0x3c)
        let noteOn = MIDIChannelMessage.noteOn(channel, key, MIDIData1Value(100))
        let noteOff = MIDIChannelMessage.noteOff(channel, key, MIDIData1Value(64))
        let track = SMFTrack(events: [.midi(.zero, noteOn),
                                      .midi(SMFEventTime(96), noteOff),
                                      .meta(SMFEventTime(96), .endOfTrack)])
        let sequence = SMFSequence(format: .format1,
                                   division: .metrical(SMFTickRate(480)),
                                   tracks: [track])
        let work = try MIDI.Importer().convert(sequence)

        guard case let .keyboardBeat(parts, _) = work.content
        else { Issue.record("Expected keyboardBeat content"); return }

        #expect(parts.map(\.name) == ["Channel 1"])
    }

    @Test
    func read_emptyData_throws() {
        let wrapper = FileWrapper(regularFileWithContents: Data())

        #expect(throws: (any Error).self) {
            try MIDI.Importer().read(from: wrapper, as: .midi)
        }
    }

    @Test
    func read_unsupportedFormat_throws() {
        let wrapper = FileWrapper(regularFileWithContents: Data())

        #expect(throws: (any Error).self) {
            try MIDI.Importer().read(from: wrapper, as: .abc)
        }
    }

    @Test
    func read_validData_returnsWork() throws {
        let track = SMFTrack(events: [.meta(.zero, .endOfTrack)])
        let sequence = SMFSequence(format: .format1,
                                   division: .metrical(SMFTickRate(480)),
                                   tracks: [track])
        let data = try MIDI.Formatter().format(sequence)
        let wrapper = FileWrapper(regularFileWithContents: data)

        let works = try MIDI.Importer().read(from: wrapper, as: .midi)

        #expect(works.count == 1)
    }

    @Test
    func readableFileFormats_containsMIDI() {
        #expect(MIDI.Importer().readableFileFormats.contains(.midi))
    }
}
