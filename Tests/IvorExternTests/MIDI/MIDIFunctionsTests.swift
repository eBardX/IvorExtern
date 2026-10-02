// © 2025–2026 John Gary Pusey (see LICENSE.md)

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
    func determineTimeCode_beat_readsTempoMapAtBeatZero() throws {
        var tempoMap = TempoMap()

        tempoMap.insert(beatTime: .zero, tempo: 120, extras: _timeCodeExtras("29.97DF", 80))

        let content = Work.Content.standardBeat([], tempoMap)
        let timeCode = try #require(SMFTimeCode(frameRate: .fps2997Drop, ticksPerFrame: 80))

        #expect(determineTimeCode(content) == timeCode)
    }

    @Test
    func determineTimeCode_beat_ignoresLaterTempoMapEntries() {
        var tempoMap = TempoMap()

        tempoMap.insert(beatTime: .zero, tempo: 120)
        tempoMap.insert(beatTime: BeatTime(4), tempo: 60, extras: _timeCodeExtras("25", 40))

        #expect(determineTimeCode(.keyboardBeat([], tempoMap)) == nil)
    }

    @Test
    func determineTimeCode_none() {
        #expect(determineTimeCode(.keyboardBeat([], TempoMap())) == nil)
        #expect(determineTimeCode(.keyboardWall([Part(name: "Piano")])) == nil)
    }

    @Test
    func determineTimeCode_unencodable_skippedForLaterParts() throws {
        var instrumentMap1 = InstrumentMap<WallTime>()
        var instrumentMap2 = InstrumentMap<WallTime>()

        instrumentMap1.insert(time: .zero, instrument: .vanilla, extras: _timeCodeExtras("29.97", 40))
        instrumentMap2.insert(time: .zero, instrument: .vanilla, extras: _timeCodeExtras("30", 10))

        let content = Work.Content.keyboardWall([Part(name: "A", instrumentMap: instrumentMap1),
                                                 Part(name: "B", instrumentMap: instrumentMap2)])
        let timeCode = try #require(SMFTimeCode(frameRate: .fps30, ticksPerFrame: 10))

        #expect(determineTimeCode(content) == timeCode)
    }

    @Test
    func determineTimeCode_wall_readsInstrumentMapAtTimeZero() throws {
        var instrumentMap = InstrumentMap<WallTime>()

        instrumentMap.insert(time: .zero, instrument: .vanilla, extras: _timeCodeExtras("25", 40))

        let absolute = Work.Content.absoluteWall([Part(name: "Piano", instrumentMap: instrumentMap)])
        let standard = Work.Content.standardWall([Part(name: "Piano", instrumentMap: instrumentMap)])
        let timeCode = try #require(SMFTimeCode(frameRate: .fps25, ticksPerFrame: 40))

        #expect(determineTimeCode(absolute) == timeCode)
        #expect(determineTimeCode(standard) == timeCode)
    }

    @Test
    func determineTimeCode_wall_ignoresLaterInstrumentMapEntries() {
        var instrumentMap = InstrumentMap<WallTime>()

        instrumentMap.insert(time: WallTime(1_000), instrument: .vanilla, extras: _timeCodeExtras("25", 40))

        #expect(determineTimeCode(.keyboardWall([Part(name: "Piano", instrumentMap: instrumentMap)])) == nil)
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

// MARK: -

extension MIDIFunctionsTests {
    private func _timeCodeExtras(_ frameRate: String,
                                 _ ticksPerFrame: Int) -> Extras {
        Extras(elements: [Extra(name: Extra.midiTimeCode.name,
                                values: [.string(frameRate), .int(ticksPerFrame)])])
    }
}
