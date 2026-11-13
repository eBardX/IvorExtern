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
    func convertToMeter_readsAPowerOfTwoDenominator() throws {
        let timeSignature = try #require(SMFTimeSignature(numerator: 6, denominator: 3, clockRate: 36, beatRate: 8))

        #expect(convertToMeter(timeSignature) == meter("6/8"))
    }

    @Test
    func convertToMIDIEventTime_scalesByTickRate() throws {
        let eventTime = try #require(convertToMIDIEventTime(beat(1, 2), SMFTickRate(480)))

        // Half a whole note is two quarter notes.
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
    func convertToMIDITempo_dividesFifteenMillionBySpeed() {
        // ♩ = 120 is 30 whole notes per minute: 15,000,000 / 30.
        #expect(convertToMIDITempo(Tempo(120))?.uintValue == 500_000)
        // ♩. = 90 is 135/4 whole notes per minute: 444,444.4…, rounded.
        #expect(convertToMIDITempo(tempo("3/8=90"))?.uintValue == 444_444)
    }

    @Test
    func convertToMIDITempo_roundTripsMicroseconds() {
        // 597,015 µs is ♩ = 4,000,000/39,801, kept exactly on import.
        let imported = convertToTempo(SMFTempo(597_015))

        #expect(convertToMIDITempo(imported)?.uintValue == 597_015)
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

    @Test(arguments: ["free", "4/3", "7/12"])
    func convertToMIDITimeSignature_noStandIn_returnsNil(_ plain: String) {
        #expect(convertToMIDITimeSignature(meter(plain), nil) == nil)
    }

    @Test
    func convertToMIDITimeSignature_readsTheMIDITimeSignatureExtra() throws {
        let extras = Extras(elements: [Extra(name: Extra.midiTimeSignature.name,
                                             values: [.int(36), .int(8)])])
        let timeSignature = try #require(convertToMIDITimeSignature(meter("6/8"), extras))

        #expect(timeSignature.clockRate == 36)
        #expect(timeSignature.beatRate == 8)
    }

    @Test(arguments: [("4/4", "4/4"),
                      ("6/8", "6/8"),
                      ("2+2+3/8", "7/8"),
                      ("6/12", "2/4"),
                      ("3/12", "1/4"),
                      ("3/6", "2/4"),
                      ("3/3", "4/4")])
    func convertToMIDITimeSignature_writesTheMeterOrAStandIn(_ plain: String,
                                                             _ expected: String) throws {
        let timeSignature = try #require(convertToMIDITimeSignature(meter(plain), nil))

        #expect(convertToMeter(timeSignature) == meter(expected))
        #expect(timeSignature.clockRate == 24)
        #expect(timeSignature.beatRate == 8)
    }

    @Test
    func convertToMIDITimeSignatureExtras_defaults_returnsNil() {
        #expect(convertToMIDITimeSignatureExtras(.default) == nil)
    }

    @Test
    func convertToMIDITimeSignatureExtras_keepsClocksPerClick() throws {
        let timeSignature = try #require(SMFTimeSignature(numerator: 6, denominator: 3, clockRate: 36, beatRate: 8))

        #expect(convertToMIDITimeSignatureExtras(timeSignature)?.elements.first?.values == [.int(36), .int(8)])
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
    func convertToTempo_500000Microseconds_isQuarterAt120() {
        #expect(convertToTempo(SMFTempo(500_000)) == Tempo(120))
    }

    @Test
    func convertToTempo_inexactRate_isExact() {
        // 60,000,000 / 450,000 = 400/3.
        #expect(convertToTempo(SMFTempo(450_000)) == tempo("1/4=400/3"))
    }

    @Test
    func determineTimeCode_beat_readsWorkExtras() throws {
        let work = Work(content: .standardBeat([], TempoMap(), MeterTable()),
                        extras: timeCodeExtras("29.97DF", 80))
        let timeCode = try #require(SMFTimeCode(frameRate: .fps2997Drop, ticksPerFrame: 80))

        #expect(determineTimeCode(work) == timeCode)
    }

    @Test
    func determineTimeCode_ignoresMapEntries() {
        var tempoMap = TempoMap()
        var instrumentTable = InstrumentTable<WallTime>()

        tempoMap.insert(beatTime: .zero, tempo: Tempo(120), extras: timeCodeExtras("25", 40))
        instrumentTable.insert(time: .zero, instrument: .vanilla, extras: timeCodeExtras("25", 40))

        #expect(determineTimeCode(Work(content: .keyboardBeat([], tempoMap, MeterTable()))) == nil)
        #expect(determineTimeCode(Work(content: .keyboardWall([Part(name: "Piano", instrumentTable: instrumentTable)]))) == nil)
    }

    @Test
    func determineTimeCode_none() {
        #expect(determineTimeCode(Work(content: .keyboardBeat([], TempoMap(), MeterTable()))) == nil)
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

    @Test(arguments: ["4/4", "5/8", "6/12"])
    func makeMeterMarker_exactOrStandInTimeSignature_returnsNil(_ plain: String) {
        #expect(makeMeterMarker(meter(plain)) == nil)
    }

    @Test(arguments: [("free", "Ivor meter free"),
                      ("4/3", "Ivor meter 4/3"),
                      ("2+2+3/8", "Ivor meter 2+2+3/8"),
                      ("2+2+2/12", "Ivor meter 2+2+2/12")])
    func makeMeterMarker_inexactTimeSignature_writesTheMeter(_ plain: String,
                                                             _ expected: String) {
        #expect(makeMeterMarker(meter(plain))?.stringValue == expected)
    }

    @Test(arguments: ["Verse", "Ivor meter", "Ivor meter 0/4"])
    func parseMeterMarker_otherText_returnsNil(_ text: String) {
        #expect(parseMeterMarker(text) == nil)
    }

    @Test
    func parseMeterMarker_readsTheMeter() {
        #expect(parseMeterMarker("Ivor meter 2+2+3/8") == meter("2+2+3/8"))
        #expect(parseMeterMarker("Ivor meter free") == .free)
    }

    @Test
    func parseSongInformation_readsTagsInOrder() {
        let tags = parseSongInformation("{@LATIN}{#Title=Yesterday}{#Composer=Someone}{#}")

        #expect(tags.map(\.name) == ["Title", "Composer"])
        #expect(tags.map(\.value) == ["Yesterday", "Someone"])
    }
}
