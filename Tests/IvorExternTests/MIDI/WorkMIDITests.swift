// © 2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import IvorMIDI
import IvorModel
import IvorSMF
import IvorSMPTE
import IvorTiming
import Testing
import XestiTools

struct WorkMIDITests {
}

// MARK: -

extension WorkMIDITests {
    @Test
    func hasMIDITimeCode_importedBeatTime() throws {
        let timeCode = try #require(SMFTimeCode(frameRate: .fps25, ticksPerFrame: 40))
        let tempoTrack = SMFTrack(events: [.meta(.zero, .tempo(SMFTempo(500_000))),
                                           .meta(.zero, .endOfTrack)])
        let work = try MIDI.Importer().convert(SMFSequence(format: .format1,
                                                           division: .timeCode(timeCode),
                                                           tracks: [tempoTrack, _noteTrack()]))

        #expect(work.timeBasis == .beat)
        #expect(work.hasMIDITimeCode)
    }

    @Test
    func hasMIDITimeCode_importedMetrical() throws {
        let work = try MIDI.Importer().convert(SMFSequence(format: .format1,
                                                           division: .metrical(SMFTickRate(480)),
                                                           tracks: [SMFTrack(events: [.meta(.zero, .endOfTrack)]),
                                                                    _noteTrack()]))

        #expect(!work.hasMIDITimeCode)
    }

    @Test
    func hasMIDITimeCode_importedWallTime() throws {
        let timeCode = try #require(SMFTimeCode(frameRate: .fps2997Drop, ticksPerFrame: 80))
        let work = try MIDI.Importer().convert(SMFSequence(format: .format1,
                                                           division: .timeCode(timeCode),
                                                           tracks: [SMFTrack(events: [.meta(.zero, .endOfTrack)]),
                                                                    _noteTrack()]))

        #expect(work.timeBasis == .wall)
        #expect(work.hasMIDITimeCode)
    }

    @Test
    func hasMIDITimeCode_newWork() {
        let work = Work(name: "New", content: .keyboardWall([Part(name: "Piano")]))

        #expect(!work.hasMIDITimeCode)
    }

    @Test
    func hasMIDITimeCode_unencodable() {
        var instrumentMap = InstrumentMap<WallTime>()

        instrumentMap.insert(time: .zero,
                             instrument: .vanilla,
                             extras: Extras(elements: [Extra(name: Extra.midiTimeCode.name,
                                                             values: [.string("29.97"), .int(40)])]))

        let work = Work(name: "Wall", content: .keyboardWall([Part(name: "Piano", instrumentMap: instrumentMap)]))

        #expect(!work.hasMIDITimeCode)
    }
}

// MARK: -

extension WorkMIDITests {
    private func _noteTrack() -> SMFTrack {
        let key = MIDIData1Value(60)

        return SMFTrack(events: [.midi(SMFEventTime(100), .noteOn(MIDIChannel(1), key, MIDIData1Value(100))),
                                 .midi(SMFEventTime(200), .noteOff(MIDIChannel(1), key, MIDIData1Value(64))),
                                 .meta(SMFEventTime(200), .endOfTrack)])
    }
}
