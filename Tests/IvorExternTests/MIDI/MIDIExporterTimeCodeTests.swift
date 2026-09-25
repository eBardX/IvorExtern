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
    func convert_smpteOffset_unsupportedFrameRate_omitted() throws {
        var tempoMap = TempoMap()

        tempoMap.insert(beatTime: .zero,
                        tempo: 120,
                        extras: Extras(elements: [Extra(name: Extra.smpteOffset.name,
                                                        values: [.string("50"), .string("01:00:00:00")])]))

        let work = Work(name: "Offset", content: .keyboardBeat([], tempoMap))
        let sequence = try MIDI.Exporter().convert(work)
        let hasOffset = sequence.tracks[0].events.contains {
            if case .meta(_, .smpteOffset) = $0 { true } else { false }
        }

        #expect(!hasOffset)
        #expect(sequence.division == .metrical(SMFTickRate(480)))
    }

    @Test
    func convert_smpteOffset_writesMetaEvent() throws {
        var tempoMap = TempoMap()

        tempoMap.insert(beatTime: .zero,
                        tempo: 120,
                        extras: Extras(elements: [Extra(name: Extra.smpteOffset.name,
                                                        values: [.string("25"), .string("01:00:00:00")])]))

        let work = Work(name: "Offset", content: .keyboardBeat([], tempoMap))
        let sequence = try MIDI.Exporter().convert(work)
        let offsets = sequence.tracks[0].events.compactMap { event -> SMPTETime? in
            guard case let .meta(.zero, .smpteOffset(offset)) = event
            else { return nil }

            return offset
        }

        #expect(offsets == [SMPTETime(string: "01:00:00:00", frameRate: .fps25)])
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
        let timeCode = try #require(SMFTimeCode(frameRate: .fps2997, ticksPerFrame: 80))
        let offset = try #require(SMPTETime(string: "00:59:58;00", frameRate: .fps2997))
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
}
