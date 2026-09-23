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
    func convert_bankSelectPrecedingProgramChange_populatesMidiBankExtra() throws {
        let channel = MIDIChannel(1)
        let bankSelectMSB = MIDIChannelMessage.controlChange(channel, .bankSelectMSB, MIDIData1Value(1))
        let bankSelectLSB = MIDIChannelMessage.controlChange(channel, .bankSelectLSB, MIDIData1Value(2))
        let programChange = MIDIChannelMessage.programChange(channel, MIDIData1Value(40))
        let track = SMFTrack(events: [.midi(.zero, bankSelectMSB),
                                      .midi(.zero, bankSelectLSB),
                                      .midi(.zero, programChange),
                                      .meta(.zero, .endOfTrack)])
        let sequence = SMFSequence(format: .format1,
                                   division: .metrical(SMFTickRate(480)),
                                   tracks: [track])
        let work = try MIDI.Importer().convert(sequence)

        guard case let .keyboardBeat(parts, _) = work.content
        else { Issue.record("Expected keyboardBeat content"); return }

        var foundBank: Int?

        parts.first?.instrumentMap.forEach { _, _, _, extras in
            foundBank = intValue(extras, .midiBank)
        }

        // MSB 1, LSB 2 -> (1 << 7) | 2 == 130, plus the 1-based convention.
        #expect(foundBank == 131)
    }

    @Test
    func convert_instrumentNameEvent_emptyText_fallsBackToGeneralMIDIName() throws {
        let emptyName = try #require(SMFText(stringValue: ""))
        let programChange = MIDIChannelMessage.programChange(MIDIChannel(1), MIDIData1Value(40))
        let track = SMFTrack(events: [.meta(.zero, .instrumentName(emptyName)),
                                      .midi(.zero, programChange),
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
    func convert_instrumentNameEvent_precedingProgramChange_overridesGeneralMIDIName() throws {
        let name = try #require(SMFText(stringValue: "Fiddle"))
        let programChange = MIDIChannelMessage.programChange(MIDIChannel(1), MIDIData1Value(40))
        let track = SMFTrack(events: [.meta(.zero, .instrumentName(name)),
                                      .midi(.zero, programChange),
                                      .meta(.zero, .endOfTrack)])
        let sequence = SMFSequence(format: .format1,
                                   division: .metrical(SMFTickRate(480)),
                                   tracks: [track])
        let work = try MIDI.Importer().convert(sequence)

        guard case let .keyboardBeat(parts, _) = work.content
        else { Issue.record("Expected keyboardBeat content"); return }

        #expect(parts.first?.instrumentMap[.zero] == Instrument("Fiddle"))
    }

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
    func convert_namedTrackWithPaddedName_normalizesName() throws {
        let paddedName = try #require(SMFText(stringValue: "  Right\tHand\u{0}\u{0}"))
        let otherName = try #require(SMFText(stringValue: "Left Hand"))
        let noteOn = MIDIChannelMessage.noteOn(MIDIChannel(1), MIDIData1Value(0x3c), MIDIData1Value(100))
        let noteOff = MIDIChannelMessage.noteOff(MIDIChannel(1), MIDIData1Value(0x3c), MIDIData1Value(64))
        let paddedTrack = SMFTrack(events: [.meta(.zero, .sequenceTrackName(paddedName)),
                                            .midi(.zero, noteOn),
                                            .midi(SMFEventTime(96), noteOff)])
        let otherTrack = SMFTrack(events: [.meta(.zero, .sequenceTrackName(otherName)),
                                           .midi(.zero, noteOn),
                                           .midi(SMFEventTime(96), noteOff)])
        let sequence = SMFSequence(format: .format1,
                                   division: .metrical(SMFTickRate(480)),
                                   tracks: [paddedTrack, otherTrack])
        let work = try MIDI.Importer().convert(sequence)

        guard case let .keyboardBeat(parts, _) = work.content
        else { Issue.record("Expected keyboardBeat content"); return }

        #expect(parts.map(\.name) == ["Right Hand", "Left Hand"])
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
    func convert_programChangeEvent_populatesMidiChannelExtra() throws {
        let channel = MIDIChannel(3)
        let programChange = MIDIChannelMessage.programChange(channel, MIDIData1Value(40))
        let track = SMFTrack(events: [.midi(.zero, programChange),
                                      .meta(.zero, .endOfTrack)])
        let sequence = SMFSequence(format: .format1,
                                   division: .metrical(SMFTickRate(480)),
                                   tracks: [track])
        let work = try MIDI.Importer().convert(sequence)

        guard case let .keyboardBeat(parts, _) = work.content
        else { Issue.record("Expected keyboardBeat content"); return }

        var foundChannel: Int?

        parts.first?.instrumentMap.forEach { _, _, _, extras in
            foundChannel = intValue(extras, .midiChannel)
        }

        #expect(foundChannel == 3)
    }

    @Test
    func convert_singleNamedTrack_leavesTrackNameOffParts() throws {
        // A Format 0 file: the lone track's name is the song's title.
        let title = try #require(SMFText(stringValue: "My Song"))
        let key = MIDIData1Value(0x3c)
        let track = SMFTrack(events: [.meta(.zero, .sequenceTrackName(title)),
                                      .midi(.zero, .noteOn(MIDIChannel(1), key, MIDIData1Value(100))),
                                      .midi(SMFEventTime(96), .noteOff(MIDIChannel(1), key, MIDIData1Value(64))),
                                      .midi(.zero, .noteOn(MIDIChannel(2), key, MIDIData1Value(100))),
                                      .midi(SMFEventTime(96), .noteOff(MIDIChannel(2), key, MIDIData1Value(64)))])
        let sequence = SMFSequence(format: .format0,
                                   division: .metrical(SMFTickRate(480)),
                                   tracks: [track])
        let work = try MIDI.Importer().convert(sequence)

        guard case let .keyboardBeat(parts, _) = work.content
        else { Issue.record("Expected keyboardBeat content"); return }

        #expect(work.name == "My Song")
        #expect(parts.map(\.name) == ["Channel 1", "Channel 2"])
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
    func convert_unnamedTrackOnChannel10WithProgramChange_partNamedPercussion() throws {
        let track = SMFTrack(events: [.midi(.zero, .programChange(MIDIChannel(10), MIDIData1Value(0)))])

        #expect(try unnamedPartNames(track) == ["Percussion"])
    }

    @Test
    func convert_unnamedTrackWithInstrumentName_partNamedByInstrumentName() throws {
        let name = try #require(SMFText(stringValue: "Fiddle"))
        let track = SMFTrack(events: [.meta(.zero, .instrumentName(name)),
                                      .midi(.zero, .programChange(MIDIChannel(10), MIDIData1Value(40)))])

        #expect(try unnamedPartNames(track) == ["Fiddle"])
    }

    @Test
    func convert_unnamedTrackWithProgramChange_partNamedByGeneralMIDIName() throws {
        let track = SMFTrack(events: [.midi(.zero, .programChange(MIDIChannel(1), MIDIData1Value(40)))])

        #expect(try unnamedPartNames(track) == ["Violin"])
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

// MARK: -

extension MIDIImporterTests {
    func unnamedPartNames(_ track: SMFTrack) throws -> [String] {
        let sequence = SMFSequence(format: .format1,
                                   division: .metrical(SMFTickRate(480)),
                                   tracks: [track])
        let work = try MIDI.Importer().convert(sequence)

        guard case let .keyboardBeat(parts, _) = work.content
        else { Issue.record("Expected keyboardBeat content"); return [] }

        return parts.map(\.name)
    }
}
