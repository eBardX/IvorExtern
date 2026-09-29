// © 2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import IvorModel
import IvorSMF
import IvorSMPTE
import Testing
import XestiTools

struct MIDIImporterTimeCodeTests {
}

// MARK: -

extension MIDIImporterTimeCodeTests {
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
}
