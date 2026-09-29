// © 2026 John Gary Pusey (see LICENSE.md)

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

struct MIDIExporterTimeCodeTests {
}

// MARK: -

extension MIDIExporterTimeCodeTests {
    @Test
    func convert_smpteOffset_impliedByMetricalDivision_omitted() throws {
        let work = Work(name: "Offset", content: .keyboardBeat([], TempoMap()))

        #expect(try _offsets(in: MIDI.Exporter().convert(work)).isEmpty)
    }

    @Test
    func convert_smpteOffset_impliedByTimeCodeDivision_omitted() throws {
        let work = try Work(name: "Offset",
                            content: .keyboardWall([]),
                            smpteStartTime: #require(SMPTETime(string: "00:00:00:00", frameRate: .fps25)))

        #expect(try _offsets(in: MIDI.Exporter().convert(work)).isEmpty)
    }

    @Test
    func convert_smpteOffset_unimpliedZero_written() throws {
        let startTime = try #require(SMPTETime(string: "00:00:00:00", frameRate: .fps30))
        let work = Work(name: "Offset",
                        content: .keyboardBeat([], TempoMap()),
                        smpteStartTime: startTime)

        #expect(try _offsets(in: MIDI.Exporter().convert(work)) == [startTime])
    }

    @Test
    func convert_smpteOffset_unsupportedFrameRate_omitted() throws {
        let work = try Work(name: "Offset",
                            content: .keyboardBeat([], TempoMap()),
                            smpteStartTime: #require(SMPTETime(string: "01:00:00:00", frameRate: .fps50)))
        let sequence = try MIDI.Exporter().convert(work)

        #expect(_offsets(in: sequence).isEmpty)
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
        #expect(_offsets(in: exported).isEmpty)
    }

    @Test
    func convert_smpteOffset_writesMetaEvent() throws {
        let startTime = try #require(SMPTETime(string: "01:00:00:00", frameRate: .fps25))
        let work = Work(name: "Offset",
                        content: .keyboardBeat([], TempoMap()),
                        smpteStartTime: startTime)
        let sequence = try MIDI.Exporter().convert(work)

        #expect(_offsets(in: sequence) == [startTime])
        #expect(sequence.division == .metrical(SMFTickRate(480)))
    }

    @Test
    func convert_timeCode_writesTimeCodeDivision() throws {
        var table = NoteTable<BeatTime, NoteNumber>()

        table.insert(attack: BeatTime(2), duration: BeatDuration(3), pitch: NoteNumber(60))

        var tempoMap = TempoMap()

        tempoMap.insert(beatTime: .zero,
                        tempo: 120,
                        extras: Extras(elements: [Extra(name: Extra.midiTimeCode.name,
                                                        values: [.string("25"), .int(40)])]))
        tempoMap.insert(beatTime: BeatTime(4), tempo: 120)
        tempoMap.insert(beatTime: BeatTime(4), tempo: 60)

        let work = Work(name: "TimeCode", content: .keyboardBeat([Part(name: "Piano", noteTable: table)], tempoMap))
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
        var tempoMap = TempoMap()

        tempoMap.insert(beatTime: .zero,
                        tempo: 120,
                        extras: Extras(elements: [Extra(name: Extra.midiTimeCode.name,
                                                        values: [.string(frameRate), .int(ticksPerFrame)])]))

        let work = Work(name: "TimeCode", content: .keyboardBeat([], tempoMap))
        let sequence = try MIDI.Exporter().convert(work)

        #expect(sequence.division == .metrical(SMFTickRate(480)))
    }

    @Test
    func convert_timeCode_unencodable_skippedForLaterExtras() throws {
        var tempoMap = TempoMap()

        tempoMap.insert(beatTime: .zero,
                        tempo: 120,
                        extras: Extras(elements: [Extra(name: Extra.midiTimeCode.name,
                                                        values: [.string("29.97"), .int(40)])]))
        tempoMap.insert(beatTime: .zero,
                        tempo: 120,
                        extras: Extras(elements: [Extra(name: Extra.midiTimeCode.name,
                                                        values: [.string("25"), .int(40)])]))

        let work = Work(name: "TimeCode", content: .keyboardBeat([], tempoMap))
        let sequence = try MIDI.Exporter().convert(work)

        #expect(try sequence.division == .timeCode(#require(SMFTimeCode(frameRate: .fps25, ticksPerFrame: 40))))
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
}

// MARK: -

extension MIDIExporterTimeCodeTests {
    private func _offsets(in sequence: MIDI.Sequence) -> [SMPTETime] {
        sequence.tracks[0].events.compactMap { event -> SMPTETime? in
            guard case let .meta(.zero, .smpteOffset(offset)) = event
            else { return nil }

            return offset
        }
    }
}
