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

struct MIDIExporterTests {
}

// MARK: -

extension MIDIExporterTests {
    @Test
    func convert_channelIdentity_duplicateClaim_fallsBackToLowestUnclaimed() throws {
        var table = NoteTable<BeatTime, NoteNumber>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: NoteNumber(60))

        let parts = [Part(name: "Violin", noteTable: table, extras: channelExtras(3)),
                     Part(name: "Viola", noteTable: table, extras: channelExtras(3))]
        let work = Work(name: "Dup", content: .keyboardBeat(parts, TempoMap()))
        let sequence = try MIDI.Exporter().convert(work)

        let channels = sequence.tracks[1...].map { track in
            track.events.compactMap { event -> MIDIChannel? in
                guard case let .midi(_, message) = event
                else { return nil }

                return message.channel
            }.first
        }

        #expect(channels[0]?.uintValue == 3)
        #expect(channels[1]?.uintValue == 1)
    }

    @Test
    func convert_channelIdentity_nonContiguousChannels_roundTrips() throws {
        var table = NoteTable<BeatTime, NoteNumber>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: NoteNumber(60))

        let parts = [Part(name: "Flute", noteTable: table, extras: channelExtras(1)),
                     Part(name: "Oboe", noteTable: table, extras: channelExtras(5)),
                     Part(name: "Clarinet", noteTable: table, extras: channelExtras(9))]
        let work = Work(name: "NonContiguous", content: .keyboardBeat(parts, TempoMap()))

        let sequence = try MIDI.Exporter().convert(work)
        let recovered = try MIDI.Importer().convert(sequence)

        guard case let .keyboardBeat(recoveredParts, _) = recovered.content
        else { Issue.record("Expected keyboardBeat content"); return }

        let recoveredChannels = recoveredParts.map { intValue($0.extras, .midiChannel) }

        #expect(recoveredChannels == [1, 5, 9])
    }

    @Test
    func convert_channelIdentity_partWithoutChannel_takesLowestUnclaimed() throws {
        var table = NoteTable<BeatTime, NoteNumber>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: NoteNumber(60))

        let parts = [Part(name: "Channel 5", noteTable: table),
                     Part(name: "Flute", noteTable: table, extras: channelExtras(1))]
        let work = Work(name: "Renamed", content: .keyboardBeat(parts, TempoMap()))
        let sequence = try MIDI.Exporter().convert(work)

        let channels = sequence.tracks[1...].map { track in
            track.events.compactMap { event -> MIDIChannel? in
                guard case let .midi(_, message) = event
                else { return nil }

                return message.channel
            }.first
        }

        // "Flute" claims channel 1. The other part has no `midiChannel`
        // extra, and its name doesn't count, so it takes the lowest
        // unclaimed channel, 2.
        #expect(channels[0]?.uintValue == 2)
        #expect(channels[1]?.uintValue == 1)
    }

    @Test
    func convert_instrumentMap_changesMidPart_emitTwoProgramChanges() throws {
        var table = NoteTable<BeatTime, NoteNumber>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: NoteNumber(60))
        table.insert(attack: BeatTime(1), duration: BeatDuration(1), pitch: NoteNumber(62))

        var instrumentMap = InstrumentMap<BeatTime>()

        try instrumentMap.insert(time: BeatTime(0), instrument: #require(Instrument(stringValue: "Acoustic Grand Piano")))
        try instrumentMap.insert(time: BeatTime(1), instrument: #require(Instrument(stringValue: "Vibraphone")))

        let part = Part(name: "Piano",
                        noteTable: table,
                        instrumentMap: instrumentMap)
        let work = Work(name: "Test", content: .keyboardBeat([part], TempoMap()))
        let sequence = try MIDI.Exporter().convert(work)

        let programChanges = sequence.tracks[1].events.compactMap { event -> MIDI.Program? in
            guard case let .midi(_, .programChange(_, program)) = event
            else { return nil }

            return program
        }

        #expect(programChanges == [MIDI.Program(1), MIDI.Program(12)])
    }

    @Test
    func convert_instrumentMap_nameUnmatchedByProgram_emitsInstrumentNameEvent() throws {
        var instrumentMap = InstrumentMap<BeatTime>()

        try instrumentMap.insert(time: BeatTime(0),
                                 instrument: #require(Instrument(stringValue: "Fiddle")),
                                 extras: Extras(elements: [Extra(name: Extra.midiProgram.name, values: [.int(41)])]))

        let part = Part(name: "Piano",
                        noteTable: NoteTable<BeatTime, NoteNumber>(),
                        instrumentMap: instrumentMap)
        let work = Work(name: "Test", content: .keyboardBeat([part], TempoMap()))
        let sequence = try MIDI.Exporter().convert(work)
        let events = sequence.tracks[1].events

        let instrumentNames = events.compactMap { event -> String? in
            guard case let .meta(_, .instrumentName(text)) = event
            else { return nil }

            return text.stringValue
        }

        #expect(instrumentNames == ["Fiddle"])

        let nameIndex = events.firstIndex { if case .meta(_, .instrumentName) = $0 { true } else { false } }
        let programIndex = events.firstIndex { if case .midi(_, .programChange) = $0 { true } else { false } }

        #expect(try #require(nameIndex) < #require(programIndex))
    }

    @Test
    func convert_instrumentMap_present_emitsProgramChange() throws {
        var instrumentMap = InstrumentMap<BeatTime>()

        try instrumentMap.insert(time: BeatTime(0), instrument: #require(Instrument(stringValue: "Vibraphone")))

        let part = Part(name: "Piano",
                        noteTable: NoteTable<BeatTime, NoteNumber>(),
                        instrumentMap: instrumentMap)
        let work = Work(name: "Test", content: .keyboardBeat([part], TempoMap()))
        let sequence = try MIDI.Exporter().convert(work)

        let programChanges = sequence.tracks[1].events.compactMap { event -> MIDI.Program? in
            guard case let .midi(_, .programChange(_, program)) = event
            else { return nil }

            return program
        }

        #expect(programChanges == [MIDI.Program(12)])
    }

    @Test
    func convert_instrumentMap_unrecognizedName_omitsDirective() throws {
        var instrumentMap = InstrumentMap<BeatTime>()

        try instrumentMap.insert(time: BeatTime(0), instrument: #require(Instrument(stringValue: "Not A Real Instrument")))

        let part = Part(name: "Piano",
                        noteTable: NoteTable<BeatTime, NoteNumber>(),
                        instrumentMap: instrumentMap)
        let work = Work(name: "Test", content: .keyboardBeat([part], TempoMap()))
        let sequence = try MIDI.Exporter().convert(work)

        let hasProgramChange = sequence.tracks[1].events.contains {
            if case .midi(_, .programChange) = $0 {
                return true
            }
            return false
        }

        #expect(!hasProgramChange)
    }

    @Test
    func convert_keyboardBeat_empty() throws {
        let work = Work(name: "Test",
                        content: .keyboardBeat([],
                                               TempoMap()))
        let sequence = try MIDI.Exporter().convert(work)

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
        let sequence = try MIDI.Exporter().convert(work)

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
    func convert_keyboardBeat_tempoMap() throws {
        var tempoMap = TempoMap()

        tempoMap.insert(beatTime: BeatTime(0),
                        tempo: Tempo(120))
        tempoMap.insert(beatTime: BeatTime(4),
                        tempo: Tempo(120))

        let work = Work(name: "Tempo",
                        content: .keyboardBeat([],
                                               tempoMap))
        let sequence = try MIDI.Exporter().convert(work)

        let track0 = sequence.tracks[0]
        let tempoEvents = track0.events.filter {
            if case let .meta(_, msg) = $0,
               case .tempo = msg { return true }
            return false
        }

        #expect(!tempoEvents.isEmpty)
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
        let sequence = try MIDI.Exporter().convert(work)

        #expect(sequence.tracks.count == 3)

        let channels = sequence.tracks[1...].map { track in
            track.events.compactMap { event -> MIDIChannel? in
                guard case let .midi(_, message) = event
                else { return nil }

                return message.channel
            }.first
        }

        #expect(Set(channels.compactMap { $0 }).count == 2)
    }

    @Test
    func convert_midiBankExtra_emitsBankSelectBeforeProgramChange() throws {
        var instrumentMap = InstrumentMap<BeatTime>()

        try instrumentMap.insert(time: BeatTime(0),
                                 instrument: #require(Instrument(stringValue: "Vibraphone")),
                                 extras: Extras(elements: [Extra(name: Extra.midiBank.name, values: [.int(130)])]))

        let part = Part(name: "Piano",
                        noteTable: NoteTable<BeatTime, NoteNumber>(),
                        instrumentMap: instrumentMap)
        let work = Work(name: "Test", content: .keyboardBeat([part], TempoMap()))
        let sequence = try MIDI.Exporter().convert(work)
        let events = sequence.tracks[1].events

        let bankMSB = events.compactMap { event -> MIDIData1Value? in
            guard case let .midi(_, .controlChange(_, .bankSelectMSB, value)) = event
            else { return nil }

            return value
        }
        let bankLSB = events.compactMap { event -> MIDIData1Value? in
            guard case let .midi(_, .controlChange(_, .bankSelectLSB, value)) = event
            else { return nil }

            return value
        }

        // Bank 130 -> MSB 1, LSB 2.
        #expect(bankMSB == [MIDIData1Value(1)])
        #expect(bankLSB == [MIDIData1Value(2)])

        let bankIndex = events.firstIndex { if case .midi(_, .controlChange(_, .bankSelectMSB, _)) = $0 { true } else { false } }
        let programIndex = events.firstIndex { if case .midi(_, .programChange) = $0 { true } else { false } }

        #expect(try #require(bankIndex) < #require(programIndex))
    }

    @Test
    func convert_sixteenParts_succeeds() throws {
        let parts = (1...16).map {
            Part(name: "P\($0)", noteTable: NoteTable<BeatTime, NoteNumber>())
        }
        let work = Work(name: "Sixteen", content: .keyboardBeat(parts, TempoMap()))
        let sequence = try MIDI.Exporter().convert(work)

        #expect(sequence.tracks.count == 17)
    }

    @Test
    func convert_smpteOffset_impliedByMetricalDivision_omitted() throws {
        let work = Work(name: "Offset", content: .keyboardBeat([], TempoMap()))

        #expect(try smpteOffsets(in: MIDI.Exporter().convert(work)).isEmpty)
    }

    @Test
    func convert_smpteOffset_impliedByTimeCodeDivision_omitted() throws {
        let work = try Work(name: "Offset",
                            content: .keyboardWall([]),
                            smpteStartTime: #require(SMPTETime(string: "00:00:00:00", frameRate: .fps25)))

        #expect(try smpteOffsets(in: MIDI.Exporter().convert(work)).isEmpty)
    }

    @Test
    func convert_smpteOffset_unimpliedZero_written() throws {
        let startTime = try #require(SMPTETime(string: "00:00:00:00", frameRate: .fps30))
        let work = Work(name: "Offset",
                        content: .keyboardBeat([], TempoMap()),
                        smpteStartTime: startTime)

        #expect(try smpteOffsets(in: MIDI.Exporter().convert(work)) == [startTime])
    }

    @Test
    func convert_smpteOffset_unsupportedFrameRate_omitted() throws {
        let work = try Work(name: "Offset",
                            content: .keyboardBeat([], TempoMap()),
                            smpteStartTime: #require(SMPTETime(string: "01:00:00:00", frameRate: .fps50)))
        let sequence = try MIDI.Exporter().convert(work)

        #expect(smpteOffsets(in: sequence).isEmpty)
        #expect(sequence.division == .metrical(SMFTickRate(480)))
    }

    @Test
    func convert_smpteOffset_withoutOffset_roundTrips() throws {
        let timeCode = try #require(SMFTimeCode(frameRate: .fps30, ticksPerFrame: 10))
        let key = MIDIData1Value(60)
        let track = SMFTrack(events: [.midi(.zero, .noteOn(MIDIChannel(1), key, MIDIData1Value(100))),
                                      .midi(SMFEventTime(300), .noteOff(MIDIChannel(1), key, MIDIData1Value(64))),
                                      .meta(SMFEventTime(300), .endOfTrack)])
        let sequence = SMFSequence(format: .format0,
                                   division: .timeCode(timeCode),
                                   tracks: [track])
        let work = try MIDI.Importer().convert(sequence)
        let exported = try MIDI.Exporter().convert(work)

        #expect(exported.division == .timeCode(timeCode))
        #expect(smpteOffsets(in: exported).isEmpty)
    }

    @Test
    func convert_smpteOffset_writesMetaEvent() throws {
        let startTime = try #require(SMPTETime(string: "01:00:00:00", frameRate: .fps25))
        let work = Work(name: "Offset",
                        content: .keyboardBeat([], TempoMap()),
                        smpteStartTime: startTime)
        let sequence = try MIDI.Exporter().convert(work)

        #expect(smpteOffsets(in: sequence) == [startTime])
        #expect(sequence.division == .metrical(SMFTickRate(480)))
    }

    @Test
    func convert_timeCode_onTempoMapEntry_ignored() throws {
        var tempoMap = TempoMap()

        tempoMap.insert(beatTime: .zero,
                        tempo: 120,
                        extras: timeCodeExtras("25", 40))

        let work = Work(name: "TimeCode", content: .keyboardBeat([], tempoMap))
        let sequence = try MIDI.Exporter().convert(work)

        #expect(sequence.division == .metrical(SMFTickRate(480)))
    }

    @Test
    func convert_timeCode_reversedWork_keepsTimeCodeDivision() throws {
        let timeCode = try #require(SMFTimeCode(frameRate: .fps25, ticksPerFrame: 40))
        let key = MIDIData1Value(60)
        let tempoTrack = SMFTrack(events: [.meta(.zero, .tempo(SMFTempo(500_000))),
                                           .meta(SMFEventTime(2_000), .tempo(SMFTempo(1_000_000))),
                                           .meta(SMFEventTime(2_000), .endOfTrack)])
        let noteTrack = SMFTrack(events: [.midi(SMFEventTime(1_000), .noteOn(MIDIChannel(1), key, MIDIData1Value(100))),
                                          .midi(SMFEventTime(3_000), .noteOff(MIDIChannel(1), key, MIDIData1Value(64))),
                                          .meta(SMFEventTime(3_000), .endOfTrack)])
        var work = try MIDI.Importer().convert(SMFSequence(format: .format1,
                                                           division: .timeCode(timeCode),
                                                           tracks: [tempoTrack, noteTrack]))

        try work.reverse(within: nil as ClosedRange<BeatTime>?)

        #expect(try MIDI.Exporter().convert(work).division == .timeCode(timeCode))
    }

    @Test
    func convert_timeCode_roundTrips() throws {
        let timeCode = try #require(SMFTimeCode(frameRate: .fps2997Drop, ticksPerFrame: 80))
        let offset = try #require(SMPTETime(string: "00:59:58;00", frameRate: .fps2997Drop))
        let key = MIDIData1Value(60)
        let tempoTrack = SMFTrack(events: [.meta(.zero, .smpteOffset(offset)),
                                           .meta(.zero, .tempo(SMFTempo(461_538))),
                                           .meta(SMFEventTime(7_777), .tempo(SMFTempo(700_001))),
                                           .meta(SMFEventTime(7_777), .endOfTrack)])
        let noteTrack = SMFTrack(events: [.midi(SMFEventTime(1_001), .noteOn(MIDIChannel(1), key, MIDIData1Value(100))),
                                          .midi(SMFEventTime(9_999), .noteOff(MIDIChannel(1), key, MIDIData1Value(64))),
                                          .meta(SMFEventTime(9_999), .endOfTrack)])
        let sequence = SMFSequence(format: .format1,
                                   division: .timeCode(timeCode),
                                   tracks: [tempoTrack, noteTrack])
        let work = try MIDI.Importer().convert(sequence)
        let exported = try MIDI.Exporter().convert(work)
        let noteTimes = exported.tracks[1].events.compactMap { event -> UInt? in
            guard case let .midi(eventTime, message) = event
            else { return nil }

            switch message {
            case .noteOff,
                 .noteOn:
                return eventTime.uintValue

            default:
                return nil
            }
        }
        let offsets = exported.tracks[0].events.compactMap { event -> SMPTETime? in
            guard case let .meta(_, .smpteOffset(offset)) = event
            else { return nil }

            return offset
        }

        #expect(exported.division == .timeCode(timeCode))
        #expect(offsets == [offset])
        #expect(noteTimes == [1_001, 9_999])
    }

    @Test(arguments: [("29.97", 40),
                      ("60", 40),
                      ("25", 0),
                      ("25", 256),
                      ("25", -1)])
    func convert_timeCode_unencodable_fallsBackToMetrical(frameRate: String,
                                                          ticksPerFrame: Int) throws {
        let work = Work(name: "TimeCode",
                        content: .keyboardBeat([], TempoMap()),
                        extras: timeCodeExtras(frameRate, ticksPerFrame))
        let sequence = try MIDI.Exporter().convert(work)

        #expect(sequence.division == .metrical(SMFTickRate(480)))
    }

    @Test
    func convert_timeCode_writesTimeCodeDivision() throws {
        var table = NoteTable<BeatTime, NoteNumber>()

        table.insert(attack: BeatTime(2), duration: BeatDuration(3), pitch: NoteNumber(60))

        var tempoMap = TempoMap()

        tempoMap.insert(beatTime: .zero, tempo: 120)
        tempoMap.insert(beatTime: BeatTime(4), tempo: 120)
        tempoMap.insert(beatTime: BeatTime(4), tempo: 60)

        let work = Work(name: "TimeCode",
                        content: .keyboardBeat([Part(name: "Piano", noteTable: table)], tempoMap),
                        extras: timeCodeExtras("25", 40))
        let sequence = try MIDI.Exporter().convert(work)
        let noteTimes = sequence.tracks[1].events.compactMap { event -> UInt? in
            guard case let .midi(eventTime, message) = event
            else { return nil }

            switch message {
            case .noteOff,
                 .noteOn:
                return eventTime.uintValue

            default:
                return nil
            }
        }

        #expect(try sequence.division == .timeCode(#require(SMFTimeCode(frameRate: .fps25, ticksPerFrame: 40))))
        #expect(noteTimes == [1_000, 3_000])
    }

    @Test
    func convert_tooManyParts_throws() {
        let parts = (1...17).map {
            Part(name: "P\($0)",
                 noteTable: NoteTable<BeatTime, NoteNumber>())
        }
        let work = Work(name: "TooMany",
                        content: .keyboardBeat(parts,
                                               TempoMap()))

        #expect(throws: (any Error).self) {
            try MIDI.Exporter().convert(work)
        }
    }

    @Test
    func convert_track0_hasTimeSignature() throws {
        let work = Work(name: "",
                        content: .keyboardBeat([],
                                               TempoMap()))
        let sequence = try MIDI.Exporter().convert(work)
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
                        content: .standardWall([]))

        #expect(throws: (any Error).self) {
            try MIDI.Exporter().convert(work)
        }
    }

    @Test
    func convert_wall_defaultTimeCode() throws {
        var table = NoteTable<WallTime, NoteNumber>()

        table.insert(attack: WallTime(1_000_000), duration: WallDuration(500_000), pitch: NoteNumber(60))

        let work = Work(name: "Wall", content: .keyboardWall([Part(name: "Piano", noteTable: table)]))
        let sequence = try MIDI.Exporter().convert(work)
        let noteTimes = sequence.tracks[1].events.compactMap { event -> UInt? in
            guard case let .midi(eventTime, .noteOn) = event
            else { return nil }

            return eventTime.uintValue
        }
        let conductorEvents = sequence.tracks[0].events.filter {
            switch $0 {
            case .meta(_, .tempo),
                 .meta(_, .timeSignature):
                true

            default:
                false
            }
        }

        #expect(try sequence.division == .timeCode(#require(SMFTimeCode(frameRate: .fps25, ticksPerFrame: 40))))
        #expect(noteTimes == [1_000])
        #expect(conductorEvents.isEmpty)
    }

    @Test
    func convert_wall_reversedWork_keepsTimeCodeDivision() throws {
        let timeCode = try #require(SMFTimeCode(frameRate: .fps30, ticksPerFrame: 10))
        let key = MIDIData1Value(60)
        let noteTrack = SMFTrack(events: [.midi(.zero, .programChange(MIDIChannel(1), MIDIProgram(41))),
                                          .midi(.zero, .noteOn(MIDIChannel(1), key, MIDIData1Value(100))),
                                          .midi(SMFEventTime(300), .programChange(MIDIChannel(1), MIDIProgram(42))),
                                          .midi(SMFEventTime(300), .noteOff(MIDIChannel(1), key, MIDIData1Value(64))),
                                          .midi(SMFEventTime(300), .noteOn(MIDIChannel(1), key, MIDIData1Value(100))),
                                          .midi(SMFEventTime(600), .noteOff(MIDIChannel(1), key, MIDIData1Value(64))),
                                          .meta(SMFEventTime(600), .endOfTrack)])
        var work = try MIDI.Importer().convert(SMFSequence(format: .format0,
                                                           division: .timeCode(timeCode),
                                                           tracks: [noteTrack]))

        try work.reverse(within: nil as ClosedRange<WallTime>?)

        #expect(keyboardWallParts(of: work) != nil)
        #expect(try MIDI.Exporter().convert(work).division == .timeCode(timeCode))
    }

    @Test
    func convert_wall_roundTrips() throws {
        let timeCode = try #require(SMFTimeCode(frameRate: .fps2997Drop, ticksPerFrame: 80))
        let offset = try #require(SMPTETime(string: "00:59:58;00", frameRate: .fps2997Drop))
        let key = MIDIData1Value(60)
        let conductorTrack = SMFTrack(events: [.meta(.zero, .smpteOffset(offset)),
                                               .meta(.zero, .endOfTrack)])
        let noteTrack = SMFTrack(events: [.midi(SMFEventTime(1_001), .noteOn(MIDIChannel(5), key, MIDIData1Value(100))),
                                          .midi(SMFEventTime(9_999), .noteOff(MIDIChannel(5), key, MIDIData1Value(64))),
                                          .meta(SMFEventTime(9_999), .endOfTrack)])
        let sequence = SMFSequence(format: .format1,
                                   division: .timeCode(timeCode),
                                   tracks: [conductorTrack, noteTrack])
        let work = try MIDI.Importer().convert(sequence)
        let exported = try MIDI.Exporter().convert(work)
        let notes = exported.tracks[1].events.compactMap { event -> (UInt, UInt)? in
            guard case let .midi(eventTime, message) = event
            else { return nil }

            switch message {
            case let .noteOff(channel, _, _),
                 let .noteOn(channel, _, _):
                return (eventTime.uintValue, channel.uintValue)

            default:
                return nil
            }
        }
        let offsets = exported.tracks[0].events.compactMap { event -> SMPTETime? in
            guard case let .meta(_, .smpteOffset(offset)) = event
            else { return nil }

            return offset
        }

        #expect(keyboardWallParts(of: work) != nil)
        #expect(exported.division == .timeCode(timeCode))
        #expect(offsets == [offset])
        #expect(notes.map(\.0) == [1_001, 9_999])
        #expect(notes.map(\.1) == [5, 5])
    }

    @Test
    func reverse_legatoVelocities_followTheirNotes() throws {
        //
        // C4 (0–1, velocity 100) and D4 (1–2, velocity 50) reversed are D4 at 0 and C4 at 1.
        // While the velocities rode on dynamic entries, D4's moved to C4's new attack.
        //
        var table = NoteTable<BeatTime, NoteNumber>()

        table.insert(attack: BeatTime(0),
                     duration: BeatDuration(1),
                     pitch: NoteNumber(60),
                     extras: Extras(elements: [Extra(name: Extra.velocity.name, values: [.int(100)])]))
        table.insert(attack: BeatTime(1),
                     duration: BeatDuration(1),
                     pitch: NoteNumber(62),
                     extras: Extras(elements: [Extra(name: Extra.velocity.name, values: [.int(50)])]))

        var work = Work(name: "Legato", content: .keyboardBeat([Part(name: "Piano", noteTable: table)], TempoMap()))

        try work.reverse(within: nil as ClosedRange<BeatTime>?)

        let sequence = try MIDI.Exporter().convert(work)
        let noteOns = sequence.tracks[1].events.compactMap { event -> String? in
            guard case let .midi(_, message) = event,
                  case let .noteOn(_, key, velocity) = message
            else { return nil }

            return "\(key.uintValue):\(velocity.uintValue)"
        }

        #expect(noteOns == ["62:50", "60:100"])
    }

    // MIDI can only represent instantaneous tempo changes; after the first pass, further roundtrips must not alter the TempoMap.
    @Test
    func roundtrip_dynamicRamp_survivesExportReimport() throws {
        var table = NoteTable<BeatTime, NoteNumber>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(4), pitch: NoteNumber(60))

        var dynamicMap = DynamicMap<BeatTime>()

        try dynamicMap.insert(time: BeatTime(0), dynamic: #require(Dynamic(numberValue: Number(0.2))))
        try dynamicMap.insert(time: BeatTime(4), dynamic: #require(Dynamic(numberValue: Number(0.9))))

        let part = Part(name: "Piano", noteTable: table, dynamicMap: dynamicMap)
        let work = Work(name: "Ramp", content: .keyboardBeat([part], TempoMap()))

        let sequence = try MIDI.Exporter().convert(work)
        let recovered = try MIDI.Importer().convert(sequence)

        guard case let .keyboardBeat(parts, _) = recovered.content,
              let recoveredPart = parts.first
        else { Issue.record("Expected a recovered part"); return }

        #expect(recoveredPart.noteTable.timeRange != nil)
    }

    @Test
    func roundTrip_dynamicsRamp_preservesShape() throws {
        var table = NoteTable<BeatTime, NoteNumber>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(4), pitch: NoteNumber(60))

        var dynamicMap = DynamicMap<BeatTime>()

        try dynamicMap.insert(time: BeatTime(0), dynamic: #require(Dynamic(numberValue: Number(0.25))))
        try dynamicMap.insert(time: BeatTime(4), dynamic: #require(Dynamic(numberValue: Number(1.0))))

        let part = Part(name: "Piano", noteTable: table, dynamicMap: dynamicMap)
        let work = Work(name: "Dynamics", content: .keyboardBeat([part], TempoMap()))

        let recovered = try roundTrip(work,
                                      exporter: MIDI.Exporter(),
                                      importer: MIDI.Importer(),
                                      fileFormat: .midi)
        let recoveredPart = try #require(keyboardBeatParts(of: recovered)?.first)

        // MIDI attaches dynamics to note-on/note-off velocity rather than a
        // free-standing ramp, so only the endpoints survive — assert shape,
        // not an exact entry-count match.
        #expect(!recoveredPart.dynamicMap.isEmpty)
    }

    @Test
    func roundTrip_exactMicrosecondsPerQuarter_preservesSubBPMPrecision() throws {
        var tempoMap = TempoMap()

        tempoMap.insert(beatTime: BeatTime(0),
                        tempo: Tempo(147),
                        extras: Extras(elements: [Extra(name: Extra.midiTempo.name,
                                                        values: [.int(408_163)])]))

        let work = Work(name: "ExactTempo", content: .keyboardBeat([], tempoMap))

        let recovered = try roundTrip(work,
                                      exporter: MIDI.Exporter(),
                                      importer: MIDI.Importer(),
                                      fileFormat: .midi)
        let recoveredTempoMap = try #require(recovered.tempoMap)

        var found: Int?

        for entry in recoveredTempoMap where entry.beatTime == BeatTime(0) {
            found = intValue(entry.extras, .midiTempo)
        }

        #expect(found == 408_163)
    }

    @Test
    func roundTrip_expressionValue_preservesExactValue() throws {
        var table = NoteTable<BeatTime, NoteNumber>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(4), pitch: NoteNumber(60))

        var dynamicMap = DynamicMap<BeatTime>()

        dynamicMap.insert(time: BeatTime(0),
                          dynamic: .mf,
                          extras: Extras(elements: [Extra(name: Extra.expressionValue.name, values: [.int(100)])]))

        let part = Part(name: "Piano", noteTable: table, dynamicMap: dynamicMap)
        let work = Work(name: "Expression", content: .keyboardBeat([part], TempoMap()))

        let recovered = try roundTrip(work,
                                      exporter: MIDI.Exporter(),
                                      importer: MIDI.Importer(),
                                      fileFormat: .midi)
        let recoveredPart = try #require(keyboardBeatParts(of: recovered)?.first)

        var found: Int?

        for entry in recoveredPart.dynamicMap {
            if let value = intValue(entry.extras, .expressionValue) {
                found = value
            }
        }

        #expect(found == 100)
    }

    @Test
    func roundTrip_info_preservesWhatMIDICanHold() throws {
        let recovered = try roundTrip(sampleMIDIWork(),
                                      exporter: MIDI.Exporter(),
                                      importer: MIDI.Importer(),
                                      fileFormat: .midi)
        let info = recovered.info
        let part = try #require(keyboardBeatParts(of: recovered)?.first)
        let entry = try #require(part.instrumentMap.first)

        #expect(recovered.name == "Aubade")
        #expect(info.title == "Aubade")
        #expect(info.subtitles.isEmpty)
        #expect(info.dedication == "To my teacher\nwith thanks")
        #expect(info.credits.isEmpty)
        #expect(info.rights == [RightsNotice(text: "© 1998 Acme\n(P) 1999 Acme")].compactMap(\.self))
        #expect(info.remarks == [Remark(text: "J. Smith (composer)"),
                                 Remark(text: "history: Written at dawn")].compactMap(\.self))
        #expect(stringValue(entry.extras, .instrumentName) == "Flauto 1")
    }

    @Test
    func roundTrip_instrumentChanges_preservesEachSegment() throws {
        var table = NoteTable<BeatTime, NoteNumber>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: NoteNumber(60))
        table.insert(attack: BeatTime(1), duration: BeatDuration(1), pitch: NoteNumber(64))

        var instrumentMap = InstrumentMap<BeatTime>()

        try instrumentMap.insert(time: BeatTime(0), instrument: #require(Instrument(stringValue: "Acoustic Grand Piano")))
        try instrumentMap.insert(time: BeatTime(1), instrument: #require(Instrument(stringValue: "Violin")))

        let part = Part(name: "Lead", noteTable: table, instrumentMap: instrumentMap)
        let work = Work(name: "Instruments", content: .keyboardBeat([part], TempoMap()))

        let recovered = try roundTrip(work,
                                      exporter: MIDI.Exporter(),
                                      importer: MIDI.Importer(),
                                      fileFormat: .midi)
        let recoveredPart = try #require(keyboardBeatParts(of: recovered)?.first)

        expectInstrumentMapsMatch(recoveredPart.instrumentMap, instrumentMap)
    }

    @Test
    func roundTrip_instrumentName_unmatchedByGeneralMIDIProgram_survives() throws {
        var table = NoteTable<BeatTime, NoteNumber>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: NoteNumber(60))

        var instrumentMap = InstrumentMap<BeatTime>()

        try instrumentMap.insert(time: BeatTime(0),
                                 instrument: #require(Instrument(stringValue: "Fiddle")),
                                 extras: Extras(elements: [Extra(name: Extra.midiProgram.name, values: [.int(41)])]))

        let part = Part(name: "Lead", noteTable: table, instrumentMap: instrumentMap)
        let work = Work(name: "Instrument", content: .keyboardBeat([part], TempoMap()))

        let recovered = try roundTrip(work,
                                      exporter: MIDI.Exporter(),
                                      importer: MIDI.Importer(),
                                      fileFormat: .midi)
        let recoveredPart = try #require(keyboardBeatParts(of: recovered)?.first)

        // Program 41 is General MIDI's "Violin" — without the Instrument
        // Name meta event, this would round-trip back as "Violin" instead.
        #expect(recoveredPart.instrumentMap[.zero] == Instrument("Fiddle"))
    }

    @Test
    func roundTrip_midiKeyPressure_preservesPeakValue() throws {
        var table = NoteTable<BeatTime, NoteNumber>()

        table.insert(attack: BeatTime(0),
                     duration: BeatDuration(1),
                     pitch: NoteNumber(60),
                     extras: Extras(elements: [Extra(name: Extra.midiKeyPressure.name, values: [.int(90)])]))

        let part = Part(name: "Piano", noteTable: table)
        let work = Work(name: "KeyPressure", content: .keyboardBeat([part], TempoMap()))

        let recovered = try roundTrip(work,
                                      exporter: MIDI.Exporter(),
                                      importer: MIDI.Importer(),
                                      fileFormat: .midi)
        let recoveredPart = try #require(keyboardBeatParts(of: recovered)?.first)

        var pressure: Int?

        for note in recoveredPart.noteTable {
            pressure = intValue(note.extras, .midiKeyPressure)
        }

        #expect(pressure == 90)
    }

    @Test
    func roundTrip_midiPan_preservesCombined14BitValue() throws {
        var panMap = PanMap<BeatTime>()

        panMap.insert(time: BeatTime(0),
                      pan: .center,
                      extras: Extras(elements: [Extra(name: Extra.midiPan.name, values: [.int(9_001)])]))

        let part = Part(name: "Piano",
                        noteTable: NoteTable<BeatTime, NoteNumber>(),
                        panMap: panMap)
        let work = Work(name: "MidiPan", content: .keyboardBeat([part], TempoMap()))

        let recovered = try roundTrip(work,
                                      exporter: MIDI.Exporter(),
                                      importer: MIDI.Importer(),
                                      fileFormat: .midi)
        let recoveredPart = try #require(keyboardBeatParts(of: recovered)?.first)

        var midiPan: Int?

        for entry in recoveredPart.panMap {
            midiPan = intValue(entry.extras, .midiPan)
        }

        #expect(midiPan == 9_001)
    }

    @Test(arguments: [nil, 1, 40, 127])
    func roundTrip_midiReleaseVelocity_preservesValue(_ velocity: Int?) throws {
        var table = NoteTable<BeatTime, NoteNumber>()

        table.insert(attack: BeatTime(0),
                     duration: BeatDuration(1),
                     pitch: NoteNumber(60),
                     extras: velocity.map { Extras(elements: [Extra(name: Extra.midiReleaseVelocity.name, values: [.int($0)])]) })

        let part = Part(name: "Piano", noteTable: table)
        let work = Work(name: "ReleaseVelocity", content: .keyboardBeat([part], TempoMap()))

        let recovered = try roundTrip(work,
                                      exporter: MIDI.Exporter(),
                                      importer: MIDI.Importer(),
                                      fileFormat: .midi)
        let recoveredPart = try #require(keyboardBeatParts(of: recovered)?.first)

        var recoveredVelocities: [Int?] = []

        for note in recoveredPart.noteTable {
            recoveredVelocities.append(intValue(note.extras, .midiReleaseVelocity))
        }

        #expect(recoveredVelocities == [velocity])
    }

    @Test
    func roundTrip_midiVolume_preservesExactValue() throws {
        var table = NoteTable<BeatTime, NoteNumber>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: NoteNumber(60))

        var instrumentMap = InstrumentMap<BeatTime>()

        try instrumentMap.insert(time: BeatTime(0),
                                 instrument: #require(Instrument(stringValue: "Acoustic Grand Piano")),
                                 extras: Extras(elements: [Extra(name: Extra.midiVolume.name, values: [.double(90)])]))

        let part = Part(name: "Piano", noteTable: table, instrumentMap: instrumentMap)
        let work = Work(name: "Volume", content: .keyboardBeat([part], TempoMap()))

        let recovered = try roundTrip(work,
                                      exporter: MIDI.Exporter(),
                                      importer: MIDI.Importer(),
                                      fileFormat: .midi)
        let recoveredPart = try #require(keyboardBeatParts(of: recovered)?.first)

        var volume: Double?

        for entry in recoveredPart.instrumentMap {
            volume = doubleValue(entry.extras, .midiVolume)
        }

        // CC 7 is 7-bit (0-127), so the round trip through the 0-100 percent
        // scale isn't exact to arbitrary precision — 90% -> round(90/100*127)
        // = 114 -> 114/127*100 ≈ 89.76.
        #expect(try abs(#require(volume) - 90) < 1)
    }

    @Test
    func roundTrip_multiPart_preservesEachPartsNotes() throws {
        var table1 = NoteTable<BeatTime, NoteNumber>()

        table1.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: NoteNumber(60))

        var table2 = NoteTable<BeatTime, NoteNumber>()

        table2.insert(attack: BeatTime(0), duration: BeatDuration(2), pitch: NoteNumber(67))

        let parts = [Part(name: "P1", noteTable: table1),
                     Part(name: "P2", noteTable: table2)]
        let work = Work(name: "MultiPart", content: .keyboardBeat(parts, TempoMap()))

        let recovered = try roundTrip(work,
                                      exporter: MIDI.Exporter(),
                                      importer: MIDI.Importer(),
                                      fileFormat: .midi)
        let recoveredParts = try #require(keyboardBeatParts(of: recovered))

        #expect(recoveredParts.count == 2)

        expectNoteTablesMatch(recoveredParts[0].noteTable, table1)
        expectNoteTablesMatch(recoveredParts[1].noteTable, table2)
    }

    @Test
    func roundTrip_notes_preservesAttackDurationAndPitch() throws {
        var table = NoteTable<BeatTime, NoteNumber>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: NoteNumber(60))
        table.insert(attack: BeatTime(1), duration: BeatDuration(2), pitch: NoteNumber(64))
        table.insert(attack: BeatTime(3), duration: BeatDuration(1), pitch: NoteNumber(67))

        let part = Part(name: "Piano", noteTable: table)
        let work = Work(name: "Notes", content: .keyboardBeat([part], TempoMap()))

        let recovered = try roundTrip(work,
                                      exporter: MIDI.Exporter(),
                                      importer: MIDI.Importer(),
                                      fileFormat: .midi)
        let recoveredPart = try #require(keyboardBeatParts(of: recovered)?.first)

        expectNoteTablesMatch(recoveredPart.noteTable, table)
    }

    @Test
    func roundTrip_pan_preservesEntries() throws {
        var panMap = PanMap<BeatTime>()

        panMap.insert(time: BeatTime(0), pan: .left)
        panMap.insert(time: BeatTime(4), pan: .right)

        let part = Part(name: "Piano",
                        noteTable: NoteTable<BeatTime, NoteNumber>(),
                        panMap: panMap)
        let work = Work(name: "Pan", content: .keyboardBeat([part], TempoMap()))

        let recovered = try roundTrip(work,
                                      exporter: MIDI.Exporter(),
                                      importer: MIDI.Importer(),
                                      fileFormat: .midi)
        let recoveredPart = try #require(keyboardBeatParts(of: recovered)?.first)

        expectPanMapsMatch(recoveredPart.panMap, panMap)
    }

    @Test
    func roundtrip_panRamp_survivesExportReimport() throws {
        var panMap = PanMap<BeatTime>()

        panMap.insert(time: BeatTime(0), pan: .left)
        panMap.insert(time: BeatTime(4), pan: .right)

        let part = Part(name: "Piano",
                        noteTable: NoteTable<BeatTime, NoteNumber>(),
                        panMap: panMap)
        let work = Work(name: "PanRamp", content: .keyboardBeat([part], TempoMap()))

        let sequence = try MIDI.Exporter().convert(work)
        let recovered = try MIDI.Importer().convert(sequence)

        guard case let .keyboardBeat(parts, _) = recovered.content,
              let recoveredPart = parts.first
        else { Issue.record("Expected a recovered part"); return }

        #expect(!recoveredPart.panMap.isEmpty)
    }

    @Test
    func roundtrip_tempoMap_accelerando_isStableAfterFirstPass() throws {
        var smoothTempoMap = TempoMap()

        smoothTempoMap.insert(beatTime: BeatTime(0), tempo: Tempo(120))
        smoothTempoMap.insert(beatTime: BeatTime(8), tempo: Tempo(160))

        let originalWork = Work(name: "Accel",
                                content: .keyboardBeat([], smoothTempoMap))

        let sequence1 = try MIDI.Exporter().convert(originalWork)
        let work1 = try MIDI.Importer().convert(sequence1)

        let tempoMap1 = try #require(work1.tempoMap)

        var entries1: [(beatTime: BeatTime, tempo: Tempo)] = []

        for entry in tempoMap1 {
            entries1.append((entry.beatTime, entry.tempo))
        }

        let sequence2 = try MIDI.Exporter().convert(work1)
        let work2 = try MIDI.Importer().convert(sequence2)

        let tempoMap2 = try #require(work2.tempoMap)

        var entries2: [(beatTime: BeatTime, tempo: Tempo)] = []

        for entry in tempoMap2 {
            entries2.append((entry.beatTime, entry.tempo))
        }

        #expect(entries2.count == entries1.count)

        for i in 0..<min(entries1.count, entries2.count) {
            #expect(entries2[i].beatTime == entries1[i].beatTime,
                    "entry \(i) beatTime mismatch on second pass")
            #expect(entries2[i].tempo == entries1[i].tempo,
                    "entry \(i) tempo mismatch on second pass")
        }
    }

    @Test
    func roundtrip_tempoMap_stepChanges_areIdempotent() throws {
        var canonicalTempoMap = TempoMap()

        canonicalTempoMap.insert(beatTime: BeatTime(0), tempo: Tempo(120))
        canonicalTempoMap.insert(beatTime: BeatTime(4), tempo: Tempo(120))
        canonicalTempoMap.insert(beatTime: BeatTime(4), tempo: Tempo(140))
        canonicalTempoMap.insert(beatTime: BeatTime(8), tempo: Tempo(140))
        canonicalTempoMap.insert(beatTime: BeatTime(8), tempo: Tempo(160))

        let originalWork = Work(name: "Roundtrip",
                                content: .keyboardBeat([], canonicalTempoMap))

        var originalEntries: [(beatTime: BeatTime, tempo: Tempo)] = []

        for entry in canonicalTempoMap {
            originalEntries.append((entry.beatTime, entry.tempo))
        }

        let sequence = try MIDI.Exporter().convert(originalWork)
        let recoveredWork = try MIDI.Importer().convert(sequence)

        let recoveredTempoMap = try #require(recoveredWork.tempoMap)

        var recoveredEntries: [(beatTime: BeatTime, tempo: Tempo)] = []

        for entry in recoveredTempoMap {
            recoveredEntries.append((entry.beatTime, entry.tempo))
        }

        #expect(recoveredEntries.count == originalEntries.count)

        for i in 0..<min(originalEntries.count, recoveredEntries.count) {
            #expect(recoveredEntries[i].beatTime == originalEntries[i].beatTime,
                    "entry \(i) beatTime mismatch")
            #expect(recoveredEntries[i].tempo == originalEntries[i].tempo,
                    "entry \(i) tempo mismatch")
        }
    }

    @Test
    func roundTrip_tempoRamp_preservesStepChanges() throws {
        var tempoMap = TempoMap()

        tempoMap.insert(beatTime: BeatTime(0), tempo: Tempo(120))
        tempoMap.insert(beatTime: BeatTime(4), tempo: Tempo(120))
        tempoMap.insert(beatTime: BeatTime(4), tempo: Tempo(160))

        let work = Work(name: "Tempo", content: .keyboardBeat([], tempoMap))

        let recovered = try roundTrip(work,
                                      exporter: MIDI.Exporter(),
                                      importer: MIDI.Importer(),
                                      fileFormat: .midi)
        let recoveredTempoMap = try #require(recovered.tempoMap)

        expectTempoMapsMatch(recoveredTempoMap, tempoMap)
    }

    @Test
    func roundTrip_velocity_preservesExactValue() throws {
        var table = NoteTable<BeatTime, NoteNumber>()

        table.insert(attack: BeatTime(0),
                     duration: BeatDuration(1),
                     pitch: NoteNumber(60),
                     extras: Extras(elements: [Extra(name: Extra.velocity.name, values: [.int(77)])]))

        var dynamicMap = DynamicMap<BeatTime>()

        dynamicMap.insert(time: BeatTime(0), dynamic: .mf)

        let part = Part(name: "Piano", noteTable: table, dynamicMap: dynamicMap)
        let work = Work(name: "Velocity", content: .keyboardBeat([part], TempoMap()))

        let recovered = try roundTrip(work,
                                      exporter: MIDI.Exporter(),
                                      importer: MIDI.Importer(),
                                      fileFormat: .midi)
        let recoveredPart = try #require(keyboardBeatParts(of: recovered)?.first)

        #expect(intValue(recoveredPart.noteTable.first?.extras, .velocity) == 77)
    }

    @Test
    func writableFileFormats_containsMIDI() {
        #expect(MIDI.Exporter().writableFileFormats.contains(.midi))
    }

    @Test
    func write_emptyWorks_throwsNoWorksToExport() {
        #expect {
            try MIDI.Exporter().write(works: [], as: .midi)
        } throws: { error in
            guard let midiError = error as? MIDI.Error
            else { return false }

            if case .noWorksToExport = midiError {
                return true
            }
            return false
        }
    }

    @Test
    func write_info_writesCopyrightFirst() throws {
        let sequence = try MIDI.Exporter().convert(sampleMIDIWork())
        let conductor = try #require(sequence.tracks.first)
        let first = try #require(conductor.events.first)

        guard case let .meta(_, .copyright(text)) = first
        else { Issue.record("Expected a Copyright event first"); return }

        #expect(text.stringValue == "© 1998 Acme\n(P) 1999 Acme")
    }

    @Test
    func write_multipleWorks_throws() {
        let works = [Work(name: "A", content: .keyboardBeat([], TempoMap())),
                     Work(name: "B", content: .keyboardBeat([], TempoMap()))]

        #expect(throws: (any Error).self) {
            try MIDI.Exporter().write(works: works, as: .midi)
        }
    }

    @Test
    func write_singleWork_returnsRegularFile() throws {
        let work = Work(name: "Test", content: .keyboardBeat([], TempoMap()))
        let wrapper = try MIDI.Exporter().write(works: [work], as: .midi)

        #expect(wrapper.isRegularFile)
        #expect(wrapper.regularFileContents?.isEmpty == false)
    }

    @Test
    func write_unsupportedFormat_throws() {
        let work = Work(name: "Test", content: .keyboardBeat([], TempoMap()))

        #expect(throws: (any Error).self) {
            try MIDI.Exporter().write(works: [work], as: .abc)
        }
    }
}

// swiftlint:enable file_length
