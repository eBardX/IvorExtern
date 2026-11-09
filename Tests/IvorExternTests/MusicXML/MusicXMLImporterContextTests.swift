// © 2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import IvorModel
import IvorMXL
import IvorTiming
import IvorTuning
import Testing
import XestiNumbers

struct MusicXMLImporterContextTests {
}

// MARK: -

extension MusicXMLImporterContextTests {
    @Test
    func advance_doesNotDecreaseMeasureAdvance() {
        var context = MusicXML.Importer.Context()

        context.advance(MusicXML.Duration(numberValue: Number(numerator: 3,
                                                              denominator: 4)))
        context.cursor = MusicXML.Duration(numberValue: Number(numerator: 1,
                                                               denominator: 4))
        context.advance(MusicXML.Duration.zero)

        #expect(context.measureAdvance == MusicXML.Duration(numberValue: Number(numerator: 3,
                                                                                denominator: 4)))
    }

    @Test
    func advance_updatesCursorAndMeasureAdvance() {
        var context = MusicXML.Importer.Context()
        let duration = MusicXML.Duration(numberValue: Number(numerator: 1,
                                                             denominator: 4))

        context.advance(duration)

        #expect(context.cursor == duration)
        #expect(context.measureAdvance == duration)
    }

    @Test
    func init_defaults() {
        let context = MusicXML.Importer.Context()

        #expect(context.activeDivisions == nil)
        #expect(context.cursor == .zero)
        #expect(context.lastDuration == .zero)
        #expect(context.measureAdvance == .zero)
        #expect(context.measureStart == .zero)
        #expect(context.noteTables.isEmpty)
        #expect(context.openPedals.isEmpty)
        #expect(context.pedalEvents.isEmpty)
        #expect(context.pendingTies.isEmpty)
        #expect(context.tempoEvents.isEmpty)
        #expect(context.times.isEmpty)
        #expect(context.transposes.isEmpty)
        #expect(context.voiceIDs.isEmpty)
    }

    @Test
    func noteTable_forVoice_registersNewVoiceIDOnce() {
        var context = MusicXML.Importer.Context()

        _ = context.noteTable(forVoice: "1")
        _ = context.noteTable(forVoice: "1")
        _ = context.noteTable(forVoice: "2")

        #expect(context.voiceIDs == ["1", "2"])
    }

    @Test
    func noteTable_forVoice_returnsEmptyTableWhenUnregistered() {
        var context = MusicXML.Importer.Context()

        let table = context.noteTable(forVoice: "1")

        #expect(table.isEmpty)
    }

    @Test
    func noteTable_forVoice_returnsStoredTable() {
        var context = MusicXML.Importer.Context()
        var table = context.noteTable(forVoice: "1")

        table.insert(attack: .zero,
                     duration: BeatDuration(1),
                     pitch: "C4")
        context.noteTables["1"] = table

        let fetched = context.noteTable(forVoice: "1")

        #expect(!fetched.isEmpty)
    }

    @Test
    func recordPedals_direction_pairsStopWithItsOpenerByNumber() {
        var context = MusicXML.Importer.Context()
        let two = MXLNumberLevel(uintValue: 2)

        context.recordPedals(pedalDirection([MXLPedal(kind: .sostenuto, number: two)]), at: 0)
        context.recordPedals(pedalDirection([MXLPedal(kind: .start)]), at: 1)
        context.recordPedals(pedalDirection([MXLPedal(kind: .stop, number: two)]), at: 2)
        context.recordPedals(pedalDirection([MXLPedal(kind: .change)]), at: 3)

        #expect(context.pedalEvents.map(\.pedal) == [.sostenuto, .sustain, .sostenuto, .sustain, .sustain])
        #expect(context.pedalEvents.map(\.level) == [.on, .on, .off, .off, .on])
        #expect(context.openPedals == [1: .sustain])
    }

    @Test
    func recordPedals_direction_soundWinsOverMarkForTheSamePedal() {
        var context = MusicXML.Importer.Context()

        context.recordPedals(pedalDirection([MXLPedal(kind: .start), MXLPedal(kind: .sostenuto, number: MXLNumberLevel(uintValue: 2))],
                                            sound: MXLSound(damperPedal: .number(25))),
                             at: 0)

        #expect(context.pedalEvents.map(\.pedal) == [.sustain, .sostenuto])
        #expect(context.pedalEvents.map(\.level) == [Pedal.Level(Number(numerator: 1, denominator: 4)), .on])
    }

    @Test
    func recordPedals_sound_returnsThePedalsItSet() {
        var context = MusicXML.Importer.Context()

        let pedals = context.recordPedals(MXLSound(softPedal: .yes, sostenutoPedal: .no), at: 1)

        #expect(pedals == [.soft, .sostenuto])
        #expect(context.pedalEvents.map(\.level) == [.off, .on])
        #expect(context.pedalEvents.map(\.pedal) == [.sostenuto, .soft])
    }
}
