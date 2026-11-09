// © 2025–2026 John Gary Pusey (see LICENSE.md)

import Foundation
@testable import IvorExtern
import IvorMIDI
import IvorModel
import IvorSMF
import IvorSMPTE
import IvorTiming
import IvorTuning
import Testing
import XestiNumbers
import XestiTools

// swiftlint:disable file_length

struct MIDIImporterTests {
}

// MARK: -

extension MIDIImporterTests {
    @Test
    func convert_bankSelectPrecedingProgramChange_populatesMidiBankExtra() throws {
        let channel = MIDIChannel(1)
        let bankSelectMSB = MIDIChannelMessage.controlChange(channel, .bankSelectMSB, MIDIData1Value(1))
        let bankSelectLSB = MIDIChannelMessage.controlChange(channel, .bankSelectLSB, MIDIData1Value(2))
        let programChange = MIDIChannelMessage.programChange(channel, MIDIProgram(41))
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

        for entry in parts.first?.instrumentTable ?? InstrumentTable() {
            foundBank = intValue(entry.extras, .midiBank)
        }

        // MSB 1, LSB 2 -> (1 << 7) | 2 == 130.
        #expect(foundBank == 130)
    }

    @Test
    func convert_halfPedaling_keepsExactValues() throws {
        let pedals = try midiImportedPedals([(0, .sustain, 0),
                                             (120, .sustain, 64),
                                             (240, .sustain, 100),
                                             (360, .sustain, 0)])
        let levels = try #require(pedals[.sustain]?.map(\.level))

        #expect(levels == [.off,
                           Pedal.Level(Number(numerator: 64, denominator: 127)),
                           Pedal.Level(Number(numerator: 100, denominator: 127)),
                           .off])
    }

    @Test
    func convert_instrumentNameEvent_emptyText_fallsBackToGeneralMIDIName() throws {
        let emptyName = try #require(SMFText(stringValue: ""))
        let programChange = MIDIChannelMessage.programChange(MIDIChannel(1), MIDIProgram(41))
        let track = SMFTrack(events: [.meta(.zero, .instrumentName(emptyName)),
                                      .midi(.zero, programChange),
                                      .meta(.zero, .endOfTrack)])
        let sequence = SMFSequence(format: .format1,
                                   division: .metrical(SMFTickRate(480)),
                                   tracks: [track])
        let work = try MIDI.Importer().convert(sequence)

        guard case let .keyboardBeat(parts, _) = work.content
        else { Issue.record("Expected keyboardBeat content"); return }

        #expect(parts.first?.instrumentTable[.zero] == Instrument("Violin"))
    }

    @Test
    func convert_instrumentNameEvent_precedingProgramChange_overridesGeneralMIDIName() throws {
        let name = try #require(SMFText(stringValue: "Fiddle"))
        let programChange = MIDIChannelMessage.programChange(MIDIChannel(1), MIDIProgram(41))
        let track = SMFTrack(events: [.meta(.zero, .instrumentName(name)),
                                      .midi(.zero, programChange),
                                      .meta(.zero, .endOfTrack)])
        let sequence = SMFSequence(format: .format1,
                                   division: .metrical(SMFTickRate(480)),
                                   tracks: [track])
        let work = try MIDI.Importer().convert(sequence)

        guard case let .keyboardBeat(parts, _) = work.content
        else { Issue.record("Expected keyboardBeat content"); return }

        #expect(parts.first?.instrumentTable[.zero] == Instrument("Fiddle"))
    }

    @Test
    func convert_metaEvents_populateInfo() throws {
        let key = MIDIData1Value(60)
        let conductor = SMFTrack(events: [.meta(.zero, .copyright(SMFText("(C) 1998 Acme"))),
                                          .meta(.zero, .sequenceTrackName(SMFText("Aubade"))),
                                          .meta(.zero, .text(SMFText("Dedication: For Anna"))),
                                          .meta(.zero, .text(SMFText("Arranged for the festival"))),
                                          .meta(SMFEventTime(480), .text(SMFText("Later text"))),
                                          .meta(SMFEventTime(480), .endOfTrack)])
        let melody = SMFTrack(events: [.meta(.zero, .sequenceTrackName(SMFText("Melody"))),
                                       .meta(.zero, .text(SMFText("Play softly"))),
                                       .meta(.zero, .lyric(SMFText("{@LATIN}{#Title=Dawn Song}{#Composer=J. Smith}"))),
                                       .meta(.zero, .lyric(SMFText("{#Lyrics=A. Poet}{#Artist=The Band}{#}"))),
                                       .meta(.zero, .instrumentName(SMFText("Flauto 1"))),
                                       .midi(.zero, .programChange(MIDIChannel(1), MIDIProgram(74))),
                                       .midi(.zero, .noteOn(MIDIChannel(1), key, MIDIData1Value(100))),
                                       .midi(SMFEventTime(480), .noteOff(MIDIChannel(1), key, MIDIData1Value(64))),
                                       .meta(SMFEventTime(480), .endOfTrack)])
        let work = try MIDI.Importer().convert(SMFSequence(format: .format1,
                                                           division: .metrical(SMFTickRate(480)),
                                                           tracks: [conductor, melody]))
        let info = work.info
        let part = try #require(keyboardBeatParts(of: work)?.first)
        let entry = try #require(part.instrumentTable.first)

        #expect(info.title == "Aubade")
        #expect(info.subtitles == ["Dawn Song"])
        #expect(info.credits == [Credit(name: "J. Smith", role: .composer),
                                 Credit(name: "A. Poet", role: .lyricist),
                                 Credit(name: "The Band", role: .artist)].compactMap(\.self))
        #expect(info.rights == [RightsNotice(text: "(C) 1998 Acme")].compactMap(\.self))
        #expect(info.dedication == "For Anna")
        #expect(info.remarks == [Remark(text: "Arranged for the festival")].compactMap(\.self))
        #expect(stringValue(entry.extras, .instrumentName) == "Flauto 1")
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
    func convert_noPedalEvents_hasNoPedals() throws {
        #expect(try midiImportedPedals([]).isEmpty)
    }

    @Test
    func convert_noteOnVelocities_keptOnEachNote() throws {
        let channel = MIDIChannel(1)
        let track = SMFTrack(events: [.midi(.zero, .noteOn(channel, MIDIData1Value(60), MIDIData1Value(100))),
                                      .midi(.zero, .noteOn(channel, MIDIData1Value(64), MIDIData1Value(40))),
                                      .midi(SMFEventTime(480), .noteOff(channel, MIDIData1Value(60), MIDIData1Value(64))),
                                      .midi(SMFEventTime(480), .noteOff(channel, MIDIData1Value(64), MIDIData1Value(64))),
                                      .meta(SMFEventTime(480), .endOfTrack)])
        let sequence = SMFSequence(format: .format1,
                                   division: .metrical(SMFTickRate(480)),
                                   tracks: [track])
        let part = try #require(keyboardBeatParts(of: MIDI.Importer().convert(sequence))?.first)
        var noteVelocities: [UInt: Int?] = [:]
        var dynamicVelocities: [Int?] = []

        for note in part.noteTable {
            noteVelocities[note.startPitch.uintValue] = intValue(note.extras, .attackVelocity)
        }

        for entry in part.dynamicMap {
            dynamicVelocities.append(intValue(entry.extras, .attackVelocity))
        }

        // A chord's notes share an attack, so only the notes themselves can tell their
        // velocities apart.
        #expect(noteVelocities == [60: 100, 64: 40])
        #expect(dynamicVelocities.allSatisfy { $0 == nil })
    }

    @Test
    func convert_onePedalTablePerController() throws {
        let pedals = try midiImportedPedals([(0, .sustain, 127),
                                             (0, .sostenuto, 127),
                                             (0, .softPedal, 127),
                                             (0, .legato, 127),
                                             (0, .portamento, 127),
                                             (480, .sostenuto, 0)])

        #expect(Set(pedals.keys) == Set(Pedal.allCases))
        #expect(pedals[.sostenuto]?.map(\.level) == [.on, .off])
        #expect(pedals[.sostenuto]?.map(\.time) == [0, 1])
    }

    @Test
    func convert_programChangeEvent_populatesInstrumentTable() throws {
        let programChange = MIDIChannelMessage.programChange(MIDIChannel(1), MIDIProgram(41))
        let track = SMFTrack(events: [.midi(.zero, programChange),
                                      .meta(.zero, .endOfTrack)])
        let sequence = SMFSequence(format: .format1,
                                   division: .metrical(SMFTickRate(480)),
                                   tracks: [track])
        let work = try MIDI.Importer().convert(sequence)

        guard case let .keyboardBeat(parts, _) = work.content
        else { Issue.record("Expected keyboardBeat content"); return }

        #expect(parts.first?.instrumentTable[.zero] == Instrument("Violin"))
    }

    @Test
    func convert_programChangeEvent_putsMidiChannelExtraOnPart() throws {
        let channel = MIDIChannel(3)
        let programChange = MIDIChannelMessage.programChange(channel, MIDIProgram(41))
        let track = SMFTrack(events: [.midi(.zero, programChange),
                                      .meta(.zero, .endOfTrack)])
        let sequence = SMFSequence(format: .format1,
                                   division: .metrical(SMFTickRate(480)),
                                   tracks: [track])
        let work = try MIDI.Importer().convert(sequence)

        guard case let .keyboardBeat(parts, _) = work.content
        else { Issue.record("Expected keyboardBeat content"); return }

        var entryChannels: [Int?] = []

        for entry in parts.first?.instrumentTable ?? InstrumentTable() {
            entryChannels.append(intValue(entry.extras, .midiChannel))
        }

        #expect(intValue(parts.first?.extras, .midiChannel) == 3)
        #expect(entryChannels == [nil])
    }

    @Test
    func convert_repedalAtOneTick_keepsOffThenOn() throws {
        let pedals = try midiImportedPedals([(0, .sustain, 127),
                                             (480, .sustain, 0),
                                             (480, .sustain, 127),
                                             (960, .sustain, 0)])

        #expect(pedals[.sustain]?.map(\.time) == [0, 1, 1, 2])
        #expect(pedals[.sustain]?.map(\.level) == [.on, .off, .on, .off])
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
    func convert_smpteOffset_setsStartTimeNotTempoMapExtra() throws {
        let offset = try #require(SMPTETime(string: "01:00:00;00", frameRate: .fps2997Drop))
        let key = MIDIData1Value(60)
        let track = SMFTrack(events: [.meta(.zero, .smpteOffset(offset)),
                                      .meta(.zero, .tempo(SMFTempo(600_000))),
                                      .midi(.zero, .noteOn(MIDIChannel(1), key, MIDIData1Value(100))),
                                      .midi(SMFEventTime(480), .noteOff(MIDIChannel(1), key, MIDIData1Value(64))),
                                      .meta(SMFEventTime(480), .endOfTrack)])
        let sequence = SMFSequence(format: .format1,
                                   division: .metrical(SMFTickRate(480)),
                                   tracks: [track])
        let work = try MIDI.Importer().convert(sequence)
        let startExtras = try #require(tempoMapExtras(work, at: .zero))

        #expect(work.smpteStartTime == offset)
        #expect(intValue(startExtras, .midiTempo) == 600_000)
        #expect(startExtras.elements.count == 1)
    }

    @Test
    func convert_smpteOffset_withoutTempoEvents_insertsNoEntry() throws {
        let offset = try #require(SMPTETime(string: "00:59:58:00", frameRate: .fps25))
        let track = SMFTrack(events: [.meta(.zero, .smpteOffset(offset)),
                                      .meta(.zero, .endOfTrack)])
        let sequence = SMFSequence(format: .format1,
                                   division: .metrical(SMFTickRate(480)),
                                   tracks: [track])
        let work = try MIDI.Importer().convert(sequence)

        #expect(work.smpteStartTime == offset)
        #expect(work.tempoMap?[.zero] == .default)
        #expect(tempoMapExtras(work, at: .zero) == nil)
    }

    @Test
    func convert_smpteStartTime_defaultsWithoutSMPTETiming() throws {
        let track = SMFTrack(events: [.meta(.zero, .endOfTrack)])
        let sequence = SMFSequence(format: .format0,
                                   division: .metrical(SMFTickRate(480)),
                                   tracks: [track])
        let work = try MIDI.Importer().convert(sequence)

        #expect(work.smpteStartTime == Work.defaultSMPTEStartTime)
    }

    @Test
    func convert_smpteStartTime_fromSMPTEOffset() throws {
        let timeCode = try #require(SMFTimeCode(frameRate: .fps25, ticksPerFrame: 40))
        let offset = try #require(SMPTETime(string: "01:00:00;00", frameRate: .fps2997Drop))
        let track = SMFTrack(events: [.meta(.zero, .smpteOffset(offset)),
                                      .meta(.zero, .endOfTrack)])
        let sequence = SMFSequence(format: .format0,
                                   division: .timeCode(timeCode),
                                   tracks: [track])
        let work = try MIDI.Importer().convert(sequence)

        #expect(work.smpteStartTime == offset)
    }

    @Test
    func convert_smpteStartTime_fromTimeCodeDivision() throws {
        let timeCode = try #require(SMFTimeCode(frameRate: .fps30, ticksPerFrame: 10))
        let track = SMFTrack(events: [.meta(.zero, .endOfTrack)])
        let sequence = SMFSequence(format: .format0,
                                   division: .timeCode(timeCode),
                                   tracks: [track])
        let work = try MIDI.Importer().convert(sequence)

        #expect(work.smpteStartTime.frameRate == .fps30)
        #expect(work.smpteStartTime.description == "00:00:00:00")
    }

    @Test
    func convert_switchValues_importAsOffAndOn() throws {
        let pedals = try midiImportedPedals([(0, .sustain, 127),
                                             (480, .sustain, 0)])

        #expect(pedals[.sustain]?.map(\.level) == [.on, .off])
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
    func convert_timeCodeDivision() throws {
        let timeCode = try #require(SMFTimeCode(frameRate: .fps25, ticksPerFrame: 40))
        let key = MIDIData1Value(60)
        let tempoTrack = SMFTrack(events: [.meta(.zero, .tempo(SMFTempo(500_000))),
                                           .meta(SMFEventTime(2_000), .tempo(SMFTempo(1_000_000))),
                                           .meta(SMFEventTime(2_000), .endOfTrack)])
        let noteTrack = SMFTrack(events: [.midi(SMFEventTime(1_000), .noteOn(MIDIChannel(1), key, MIDIData1Value(100))),
                                          .midi(SMFEventTime(3_000), .noteOff(MIDIChannel(1), key, MIDIData1Value(64))),
                                          .meta(SMFEventTime(3_000), .endOfTrack)])
        let sequence = SMFSequence(format: .format1,
                                   division: .timeCode(timeCode),
                                   tracks: [tempoTrack, noteTrack])
        let work = try MIDI.Importer().convert(sequence)
        let parts = try #require(keyboardBeatParts(of: work))
        var notes: [(BeatTime, BeatDuration)] = []

        for note in parts.first?.noteTable ?? NoteTable() {
            notes.append((note.attack, note.duration))
        }

        // 1,000 ticks per second: one second at 120 BPM, then one at 60 BPM.
        #expect(notes.count == 1)
        #expect(notes.first?.0 == BeatTime(2))
        #expect(notes.first?.1 == BeatDuration(3))
        #expect(work.tempoMap?[BeatTime(4)] == Tempo(60))
        #expect(timeCodeValues(work.extras) == [.string("25"), .int(40)])
        #expect(timeCodeValues(tempoMapExtras(work, at: .zero)) == nil)
    }

    @Test
    func convert_timeCodeDivision_wallTimesMatchTimecode() throws {
        let timeCode = try #require(SMFTimeCode(frameRate: .fps2997Drop, ticksPerFrame: 80))
        let key = MIDIData1Value(60)
        let track = SMFTrack(events: [.meta(.zero, .tempo(SMFTempo(500_000))),
                                      .midi(SMFEventTime(24_000), .noteOn(MIDIChannel(1), key, MIDIData1Value(100))),
                                      .midi(SMFEventTime(24_080), .noteOff(MIDIChannel(1), key, MIDIData1Value(64))),
                                      .meta(SMFEventTime(24_080), .endOfTrack)])
        let sequence = SMFSequence(format: .format0,
                                   division: .timeCode(timeCode),
                                   tracks: [track])
        let work = try MIDI.Importer().convert(sequence)
        let parts = try #require(keyboardBeatParts(of: work))
        var attack: BeatTime?

        for note in parts.first?.noteTable ?? NoteTable() {
            attack = note.attack
        }

        // Tick 24,000 is frame 300: 00:00:10;00 in drop-frame timecode.
        let tempoMap = try #require(work.tempoMap)
        let wallTime = try TimeConverter(tempoMap: tempoMap).wallTime(at: #require(attack))
        let timecode = SMPTETimeConverter(frameRate: .fps2997Drop).smpteTime(at: SMPTEExactSeconds(wallTime.numberValue))

        #expect(timecode.description == "00:00:10;00")
    }

    @Test
    func convert_timeCodeDivision_withoutTempoEventAtZero_insertsNoEntry() throws {
        let timeCode = try #require(SMFTimeCode(frameRate: .fps25, ticksPerFrame: 40))
        let track = SMFTrack(events: [.meta(SMFEventTime(1_000), .tempo(SMFTempo(1_000_000))),
                                      .meta(SMFEventTime(1_000), .endOfTrack)])
        let sequence = SMFSequence(format: .format1,
                                   division: .timeCode(timeCode),
                                   tracks: [track])
        let work = try MIDI.Importer().convert(sequence)

        #expect(timeCodeValues(work.extras) == [.string("25"), .int(40)])
        #expect(tempoMapExtras(work, at: .zero) == nil)
    }

    @Test
    func convert_timeCodeDivision_withoutTempoEvents_importsWallTime() throws {
        let timeCode = try #require(SMFTimeCode(frameRate: .fps25, ticksPerFrame: 40))
        let key = MIDIData1Value(60)
        let track = SMFTrack(events: [.midi(SMFEventTime(1_000), .noteOn(MIDIChannel(3), key, MIDIData1Value(100))),
                                      .midi(SMFEventTime(3_500), .noteOff(MIDIChannel(3), key, MIDIData1Value(64))),
                                      .meta(SMFEventTime(3_500), .endOfTrack)])
        let sequence = SMFSequence(format: .format0,
                                   division: .timeCode(timeCode),
                                   tracks: [track])
        let work = try MIDI.Importer().convert(sequence)
        let parts = try #require(keyboardWallParts(of: work))
        var notes: [(WallTime, WallDuration)] = []

        for note in parts.first?.noteTable ?? NoteTable() {
            notes.append((note.attack, note.duration))
        }

        // 1,000 ticks per second.
        #expect(work.tempoMap == nil)
        #expect(notes.count == 1)
        #expect(notes.first?.0 == WallTime(1_000_000))
        #expect(notes.first?.1 == WallDuration(2_500_000))

        var entryCount = 0

        for _ in parts[0].instrumentTable {
            entryCount += 1
        }

        // No Program Change, so no instrument table entry; the channel is on the part itself.
        #expect(parts[0].name == "Channel 3")
        #expect(entryCount == 0)
        #expect(intValue(parts[0].extras, .midiChannel) == 3)
        #expect(timeCodeValues(work.extras) == [.string("25"), .int(40)])
    }

    @Test
    func convert_timeCodeDivision_withoutTempoEvents_leavesProgramChangeEntryAlone() throws {
        let timeCode = try #require(SMFTimeCode(frameRate: .fps30, ticksPerFrame: 10))
        let offset = try #require(SMPTETime(string: "01:00:00:00", frameRate: .fps30))
        let key = MIDIData1Value(60)
        let tempoTrack = SMFTrack(events: [.meta(.zero, .smpteOffset(offset)),
                                           .meta(.zero, .endOfTrack)])
        let noteTrack = SMFTrack(events: [.midi(.zero, .programChange(MIDIChannel(1), MIDIProgram(41))),
                                          .midi(.zero, .noteOn(MIDIChannel(1), key, MIDIData1Value(100))),
                                          .midi(SMFEventTime(300), .noteOff(MIDIChannel(1), key, MIDIData1Value(64))),
                                          .meta(SMFEventTime(300), .endOfTrack)])
        let sequence = SMFSequence(format: .format1,
                                   division: .timeCode(timeCode),
                                   tracks: [tempoTrack, noteTrack])
        let work = try MIDI.Importer().convert(sequence)
        let parts = try #require(keyboardWallParts(of: work))
        var entryCount = 0

        for _ in parts[0].instrumentTable {
            entryCount += 1
        }

        let startExtras = try #require(instrumentTableExtras(parts[0], at: .zero))

        #expect(entryCount == 1)
        #expect(intValue(startExtras, .midiProgram) == 41)
        #expect(timeCodeValues(startExtras) == nil)
        #expect(timeCodeValues(work.extras) == [.string("30"), .int(10)])
        #expect(!startExtras.elements.contains { $0.name == "smpteOffset" })
        #expect(work.smpteStartTime == offset)
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
        let track = SMFTrack(events: [.midi(.zero, .programChange(MIDIChannel(10), MIDIProgram(1)))])

        #expect(try unnamedPartNames(track) == ["Percussion"])
    }

    @Test
    func convert_unnamedTrackWithInstrumentName_partNamedByInstrumentName() throws {
        let name = try #require(SMFText(stringValue: "Fiddle"))
        let track = SMFTrack(events: [.meta(.zero, .instrumentName(name)),
                                      .midi(.zero, .programChange(MIDIChannel(10), MIDIProgram(41)))])

        #expect(try unnamedPartNames(track) == ["Fiddle"])
    }

    @Test
    func convert_unnamedTrackWithProgramChange_partNamedByGeneralMIDIName() throws {
        let track = SMFTrack(events: [.midi(.zero, .programChange(MIDIChannel(1), MIDIProgram(41)))])

        #expect(try unnamedPartNames(track) == ["Violin"])
    }

    @Test
    func convert_withoutProgramChange_putsMidiChannelExtraOnPart() throws {
        let key = MIDIData1Value(60)
        let track = SMFTrack(events: [.midi(.zero, .noteOn(MIDIChannel(7), key, MIDIData1Value(100))),
                                      .midi(SMFEventTime(480), .noteOff(MIDIChannel(7), key, MIDIData1Value(64))),
                                      .meta(SMFEventTime(480), .endOfTrack)])
        let sequence = SMFSequence(format: .format1,
                                   division: .metrical(SMFTickRate(480)),
                                   tracks: [track])
        let parts = try #require(keyboardBeatParts(of: MIDI.Importer().convert(sequence)))

        #expect(parts.first?.name == "Channel 7")
        #expect(intValue(parts.first?.extras, .midiChannel) == 7)
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

// swiftlint:enable file_length
