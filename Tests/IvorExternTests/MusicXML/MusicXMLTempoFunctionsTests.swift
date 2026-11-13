// © 2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import IvorMXL
import IvorTiming
import Testing

struct MusicXMLTempoFunctionsTests {
}

// MARK: -

extension MusicXMLTempoFunctionsTests {
    @Test
    func convertToMusicXMLMetronome_dottedUnit_keepsItsUnit() {
        #expect(metronomeText(convertToMusicXMLMetronome(tempo("3/8=90"))) == "quarter. = 90")
    }

    @Test
    func convertToMusicXMLMetronome_fractionalRate_isRounded() {
        #expect(metronomeText(convertToMusicXMLMetronome(tempo("1/4=66.5"))) == "quarter = 67")
    }

    @Test
    func convertToMusicXMLMetronome_plainUnit_keepsItsUnit() {
        #expect(metronomeText(convertToMusicXMLMetronome(tempo("1/2=60"))) == "half = 60")
    }

    @Test
    func convertToMusicXMLMetronome_tripletUnit_isRestatedInQuarters() {
        //
        // 90 sixth-notes a minute is the speed of 60 quarter notes.
        //
        #expect(metronomeText(convertToMusicXMLMetronome(tempo("1/6=90"))) == "quarter = 60")
    }

    @Test
    func convertToMusicXMLMetronome_unitWithNoNoteKind_returnsNil() {
        //
        // Sixteen whole notes is a power of two, but longer than a maxima.
        //
        #expect(convertToMusicXMLMetronome(tempo("16=1")) == nil)
    }

    @Test
    func convertToMusicXMLSound_tempo_isInQuarterNotesPerMinute() {
        #expect(convertToMusicXMLSound(tempo: tempo("3/8=80")).tempo == 120)
        #expect(convertToMusicXMLSound(tempo: Tempo(90)).tempo == 90)
    }

    @Test
    func convertToTempo_metronome_dottedBeatUnit_scalesFactor() {
        let beatUnit = MXLBeatUnit(beatUnit: .quarter,
                                   dot: 1)
        let metronome = MXLMetronome(content: .beatUnit(beatUnit,
                                                        tied: [],
                                                        content: .perMinute(MXLPerMinute(value: "80"))))

        //
        // A dotted quarter is 3/8 of a whole note, so "dotted quarter = 80"
        // keeps that unit, at the speed of 120 quarter notes per minute.
        //
        #expect(convertToTempo(metronome) == tempo("3/8=80"))
        #expect(convertToTempo(metronome)?.numberValue == Tempo(120).numberValue)
    }

    @Test
    func convertToTempo_metronome_everyBeatUnitKeepsItsValue() {
        let units: [(MXLNoteKindValue, String, String)] = [(.breve, "5", "2=5"),
                                                           (.half, "30", "1/2=30"),
                                                           (.long, "5", "4=5"),
                                                           (.maxima, "5", "8=5"),
                                                           (.n1024th, "25600", "1/1024=25600"),
                                                           (.n128th, "3200", "1/128=3200"),
                                                           (.n16th, "400", "1/16=400"),
                                                           (.n256th, "6400", "1/256=6400"),
                                                           (.n32nd, "800", "1/32=800"),
                                                           (.n512th, "12800", "1/512=12800"),
                                                           (.n64th, "1600", "1/64=1600"),
                                                           (.quarter, "100", "1/4=100"),
                                                           (.eighth, "200", "1/8=200"),
                                                           (.whole, "5", "1=5")]

        for (unit, perMinute, plain) in units {
            let metronome = MXLMetronome(content: .beatUnit(MXLBeatUnit(beatUnit: unit, dot: 0),
                                                            tied: [],
                                                            content: .perMinute(MXLPerMinute(value: perMinute))))

            #expect(convertToTempo(metronome) == tempo(plain))
        }
    }

    @Test
    func convertToTempo_metronome_metricModulation_returnsNil() {
        let metronome = MXLMetronome(content: .metronomeArrows(hasMetronomeArrows: true,
                                                               note: [],
                                                               relation: nil,
                                                               secondNote: []))

        #expect(convertToTempo(metronome) == nil)
    }

    @Test
    func convertToTempo_metronome_nonNumericPerMinute_returnsNil() {
        let beatUnit = MXLBeatUnit(beatUnit: .quarter,
                                   dot: 0)
        let metronome = MXLMetronome(content: .beatUnit(beatUnit,
                                                        tied: [],
                                                        content: .perMinute(MXLPerMinute(value: "ca. 120"))))

        #expect(convertToTempo(metronome) == nil)
    }

    @Test
    func convertToTempo_metronome_readsQuarterEqualsPerMinute() {
        let beatUnit = MXLBeatUnit(beatUnit: .quarter,
                                   dot: 0)
        let metronome = MXLMetronome(content: .beatUnit(beatUnit,
                                                        tied: [],
                                                        content: .perMinute(MXLPerMinute(value: "120"))))

        #expect(convertToTempo(metronome) == Tempo(120))
    }

    @Test
    func convertToTempo_metronome_scalesNonQuarterBeatUnit() {
        let beatUnit = MXLBeatUnit(beatUnit: .eighth,
                                   dot: 0)
        let metronome = MXLMetronome(content: .beatUnit(beatUnit,
                                                        tied: [],
                                                        content: .perMinute(MXLPerMinute(value: "160"))))

        //
        // "eighth = 160" keeps its unit, at the speed of "quarter = 80".
        //
        #expect(convertToTempo(metronome) == tempo("1/8=160"))
        #expect(convertToTempo(metronome)?.numberValue == Tempo(80).numberValue)
    }

    @Test
    func convertToTempo_sound_fractionalTempo_staysExact() {
        #expect(convertToTempo(MXLSound(tempo: 66.5)) == tempo("1/4=133/2"))
    }

    @Test
    func convertToTempo_sound_noTempo_returnsNil() {
        #expect(convertToTempo(MXLSound()) == nil)
    }

    @Test
    func convertToTempo_sound_readsQuarterNotesPerMinute() {
        #expect(convertToTempo(MXLSound(tempo: 120)) == Tempo(120))
    }

    @Test
    func convertToTempo_sound_zeroTempo_returnsNil() {
        #expect(convertToTempo(MXLSound(tempo: 0)) == nil)
    }

    @Test
    func convertToTempo_soundAndMetronome_metronomeOnly_givesItsTempo() {
        let metronome = convertToMusicXMLMetronome(tempo("3/8=80"))

        #expect(convertToTempo(sound: nil,
                               metronome: metronome) == tempo("3/8=80"))
    }

    @Test
    func convertToTempo_soundAndMetronome_neither_returnsNil() {
        #expect(convertToTempo(sound: nil,
                               metronome: nil) == nil)
    }

    @Test
    func convertToTempo_soundAndMetronome_soundOnly_givesQuarterTempo() {
        #expect(convertToTempo(sound: MXLSound(tempo: 120),
                               metronome: nil) == Tempo(120))
    }

    @Test
    func convertToTempo_soundAndMetronome_speedFromSoundInMetronomeUnit() {
        //
        // The metronome says ♩. = 70, but the sound's 120 quarter notes a
        // minute is ♩. = 80.
        //
        let metronome = convertToMusicXMLMetronome(tempo("3/8=70"))

        #expect(convertToTempo(sound: MXLSound(tempo: 120),
                               metronome: metronome) == tempo("3/8=80"))
    }

    @Test
    func makeMusicXMLTempoDirection_withMetronome_writesMarkAndSound() throws {
        let direction = makeMusicXMLTempoDirection(tempo("3/8=80"))
        let kind = try #require(direction.kind.first)

        guard case let .metronome(metronome) = kind.content
        else {
            Issue.record("Expected a metronome mark")

            return
        }

        #expect(direction.kind.count == 1)
        #expect(metronomeText(metronome) == "quarter. = 80")
        #expect(direction.sound?.tempo == 120)
    }

    @Test
    func makeMusicXMLTempoDirection_withoutMetronome_writesEmptyWords() throws {
        let direction = makeMusicXMLTempoDirection(tempo("16=1"))
        let kind = try #require(direction.kind.first)

        guard case let .words(words) = kind.content
        else {
            Issue.record("Expected an empty words placeholder")

            return
        }

        #expect(words.value.isEmpty)
        #expect(direction.sound?.tempo == 64)
    }
}
