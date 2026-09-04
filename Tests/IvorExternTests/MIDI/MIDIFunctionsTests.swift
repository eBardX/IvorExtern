// © 2025–2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import IvorMIDI
import IvorModel
import IvorTiming
import IvorTuning
import Testing
import XestiNumbers
import XestiTools

struct MIDIFunctionsTests {
}

// MARK: -

extension MIDIFunctionsTests {
    @Test
    func convertToDynamic_scalesToUnitRange() throws {
        let dynamic = try #require(convertToDynamic(MIDIData1Value(127)))

        #expect(dynamic == Dynamic(1))
    }

    @Test
    func convertToInstrument_looksUpGeneralMIDIName() {
        #expect(convertToInstrument(MIDIData1Value(40)) == Instrument("Violin"))
    }

    @Test
    func convertToMIDIEventTime_scalesByTickRate() throws {
        let eventTime = try #require(convertToMIDIEventTime(BeatTime(2), SMFTickRate(480)))

        #expect(eventTime == SMFEventTime(960))
    }

    @Test
    func convertToMIDIKeyVelocity_scalesToDataRange() throws {
        let keyVelocity = try #require(convertToMIDIKeyVelocity(Dynamic(1)))

        #expect(keyVelocity == MIDIData1Value(127))
    }

    @Test
    func convertToMIDINoteNumber_preservesValue() throws {
        let noteNumber = try #require(convertToMIDINoteNumber(NoteNumber(60)))

        #expect(noteNumber == MIDIData1Value(60))
    }

    @Test
    func convertToMIDIPanValue_scalesToDataRange() throws {
        let panValue = try #require(convertToMIDIPanValue(.right))

        #expect(panValue == MIDIData1Value(127))
    }

    @Test
    func convertToMIDITempo_convertsMicrosecondsPerQuarterNote() throws {
        let midiTempo = try #require(convertToMIDITempo(Tempo(120)))

        #expect(midiTempo == SMFTempo(500_000))
    }

    @Test
    func convertToMIDIText_preservesString() throws {
        let text = try #require(convertToMIDIText("Track Name"))

        #expect(text == SMFText("Track Name"))
    }

    @Test
    func convertToNoteNumber_preservesValue() {
        #expect(convertToNoteNumber(MIDIData1Value(60)) == NoteNumber(60))
    }

    @Test
    func convertToPan_scalesToBipolarRange() throws {
        let pan = try #require(convertToPan(MIDIData1Value(127)))

        #expect(pan == .right)
    }

    @Test
    func convertToTempo_appliesBeatMapFactor() {
        let tempo = convertToTempo(SMFTempo(500_000),
                                   Number(1))

        #expect(tempo == Tempo(120))
    }

    @Test
    func determineWorkName_noSequenceTrackNameEvent_returnsEmptyString() {
        let track = SMFTrack(events: [.meta(.zero, .endOfTrack)])
        let sequence = SMFSequence(format: .format1,
                                   division: .metrical(SMFTickRate(480)),
                                   tracks: [track])

        #expect(determineWorkName(sequence).isEmpty)
    }

    @Test
    func determineWorkName_returnsFirstTrackSequenceTrackName() {
        let track = SMFTrack(events: [.meta(.zero, .sequenceTrackName(SMFText("My Track")))])
        let sequence = SMFSequence(format: .format1,
                                   division: .metrical(SMFTickRate(480)),
                                   tracks: [track])

        #expect(determineWorkName(sequence) == "My Track")
    }
}
