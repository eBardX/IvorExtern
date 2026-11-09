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
        #expect(convertToInstrument(MIDIProgram(41)) == Instrument("Violin"))
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
    func convertToMIDIProgram_generalMIDIName_returnsProgram() {
        #expect(convertToMIDIProgram(Instrument("Violin")) == MIDIProgram(41))
    }

    @Test
    func convertToMIDIProgram_negativeFallbackForm_returnsNil() {
        #expect(convertToMIDIProgram(Instrument("Program -5")) == nil)
    }

    @Test
    func convertToMIDITempo_convertsMicrosecondsPerQuarterNote() throws {
        let midiTempo = try #require(convertToMIDITempo(Tempo(120)))

        #expect(midiTempo == SMFTempo(500_000))
    }

    @Test
    func convertToMIDIText_nonLatin1_isTransliterated() throws {
        let text = try #require(convertToMIDIText("Café ‘Acme’ — ℗ 1998"))

        #expect(text.stringValue == "Café 'Acme' - (P) 1998")
        #expect(text.bytesValue != nil)
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
    func determineTimeCode_beat_readsWorkExtras() throws {
        let work = Work(content: .standardBeat([], TempoMap()),
                        extras: timeCodeExtras("29.97DF", 80))
        let timeCode = try #require(SMFTimeCode(frameRate: .fps2997Drop, ticksPerFrame: 80))

        #expect(determineTimeCode(work) == timeCode)
    }

    @Test
    func determineTimeCode_ignoresMapEntries() {
        var tempoMap = TempoMap()
        var instrumentTable = InstrumentTable<WallTime>()

        tempoMap.insert(beatTime: .zero, tempo: 120, extras: timeCodeExtras("25", 40))
        instrumentTable.insert(time: .zero, instrument: .vanilla, extras: timeCodeExtras("25", 40))

        #expect(determineTimeCode(Work(content: .keyboardBeat([], tempoMap))) == nil)
        #expect(determineTimeCode(Work(content: .keyboardWall([Part(name: "Piano", instrumentTable: instrumentTable)]))) == nil)
    }

    @Test
    func determineTimeCode_none() {
        #expect(determineTimeCode(Work(content: .keyboardBeat([], TempoMap()))) == nil)
        #expect(determineTimeCode(Work(content: .keyboardWall([Part(name: "Piano")]))) == nil)
    }

    @Test
    func determineTimeCode_unencodable() {
        #expect(determineTimeCode(Work(extras: timeCodeExtras("29.97", 40))) == nil)
        #expect(determineTimeCode(Work(extras: timeCodeExtras("25", 0))) == nil)
        #expect(determineTimeCode(Work(extras: timeCodeExtras("25", 256))) == nil)
    }

    @Test
    func determineTimeCode_wall_readsWorkExtras() throws {
        let absolute = Work(content: .absoluteWall([Part(name: "Piano")]),
                            extras: timeCodeExtras("25", 40))
        let standard = Work(content: .standardWall([Part(name: "Piano")]),
                            extras: timeCodeExtras("25", 40))
        let timeCode = try #require(SMFTimeCode(frameRate: .fps25, ticksPerFrame: 40))

        #expect(determineTimeCode(absolute) == timeCode)
        #expect(determineTimeCode(standard) == timeCode)
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

    @Test
    func parseSongInformation_readsTagsInOrder() {
        let tags = parseSongInformation("{@LATIN}{#Title=Yesterday}{#Composer=Someone}{#}")

        #expect(tags.map(\.name) == ["Title", "Composer"])
        #expect(tags.map(\.value) == ["Yesterday", "Someone"])
    }
}
