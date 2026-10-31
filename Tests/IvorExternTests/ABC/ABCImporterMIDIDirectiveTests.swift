// © 2025–2026 John Gary Pusey (see LICENSE.md)

import Foundation
@testable import IvorExtern
import IvorModel
import IvorTiming
import IvorTuning
import Testing
import XestiNumbers
import XestiTools

struct ABCImporterMIDIDirectiveTests {
}

// MARK: -

extension ABCImporterMIDIDirectiveTests {
    @Test
    func read_bareMidiChannelDirective_populatesVanillaInstrumentWithChannelExtra() throws {
        let abc = """
            X:1
            T:Channel-Only Tune
            L:1/4
            K:C
            %%MIDI channel 3
            C D E F|
            """
        let wrapper = FileWrapper(regularFileWithContents: Data(abc.utf8))
        let works = try ABC.Importer().read(from: wrapper, as: .abc)
        let work = try #require(works.first)
        let parts = try #require(standardBeatParts(of: work))

        #expect(parts.first?.instrumentMap[.zero] == Instrument.vanilla)

        var foundChannel: Int?

        for entry in parts.first?.instrumentMap ?? InstrumentMap() {
            foundChannel = intValue(entry.extras, .midiChannel)
        }

        #expect(foundChannel == 3)
    }

    @Test
    func read_midiProgramAndStandaloneChannelDirectives_programChannelTakesPriority() throws {
        let abc = """
            X:1
            T:Both Directives Tune
            L:1/4
            K:C
            %%MIDI channel 3
            %%MIDI program 2 40
            C D E F|
            """
        let wrapper = FileWrapper(regularFileWithContents: Data(abc.utf8))
        let works = try ABC.Importer().read(from: wrapper, as: .abc)
        let work = try #require(works.first)
        let parts = try #require(standardBeatParts(of: work))

        var foundChannel: Int?

        for entry in parts.first?.instrumentMap ?? InstrumentMap() {
            foundChannel = intValue(entry.extras, .midiChannel)
        }

        #expect(parts.first?.instrumentMap[.zero] == Instrument("Violin"))
        #expect(foundChannel == 2)
    }

    @Test
    func read_midiProgramDirective_populatesInstrumentMap() throws {
        let abc = """
            X:1
            T:Instrument Tune
            L:1/4
            K:C
            %%MIDI program 40
            C D E F|
            """
        let wrapper = FileWrapper(regularFileWithContents: Data(abc.utf8))
        let works = try ABC.Importer().read(from: wrapper, as: .abc)
        let work = try #require(works.first)
        let parts = try #require(standardBeatParts(of: work))

        #expect(parts.first?.instrumentMap[.zero] == Instrument("Violin"))
    }

    @Test
    func read_midiProgramDirectivesInVoiceBodies_assignEachVoice() throws {
        let abc = """
            X:1
            T:Duet
            L:1/4
            V:1
            V:2
            K:C
            V:1
            %%MIDI program 73
            c d e f|
            V:2
            %%MIDI program 70
            C, D, E, F,|
            """
        let wrapper = FileWrapper(regularFileWithContents: Data(abc.utf8))
        let work = try #require(ABC.Importer().read(from: wrapper, as: .abc).first)
        let parts = try #require(standardBeatParts(of: work))

        #expect(parts.map { $0.instrumentMap[.zero] } == [Instrument("Flute"), Instrument("Bassoon")])
    }

    @Test
    func read_midiProgramBaseOne_countsProgramsFromOne() throws {
        let abc = """
            %%MIDI programbase 1

            X:1
            T:Standard Numbering
            L:1/4
            K:C
            %%MIDI program 41
            C D E F|
            """
        let wrapper = FileWrapper(regularFileWithContents: Data(abc.utf8))
        let work = try #require(ABC.Importer().read(from: wrapper, as: .abc).first)
        let parts = try #require(standardBeatParts(of: work))

        var programs: [Int?] = []

        for entry in parts.first?.instrumentMap ?? InstrumentMap() {
            programs.append(intValue(entry.extras, .midiProgram))
        }

        #expect(parts.first?.instrumentMap[.zero] == Instrument("Violin"))
        #expect(programs == [41])
    }

    @Test
    func read_midiProgramDirectiveWithChannel_populatesMidiChannelExtra() throws {
        let abc = """
            X:1
            T:Instrument Tune
            L:1/4
            K:C
            %%MIDI program 5 41
            C D E F|
            """
        let wrapper = FileWrapper(regularFileWithContents: Data(abc.utf8))
        let works = try ABC.Importer().read(from: wrapper, as: .abc)
        let work = try #require(works.first)
        let parts = try #require(standardBeatParts(of: work))

        var foundChannel: Int?

        for entry in parts.first?.instrumentMap ?? InstrumentMap() {
            foundChannel = intValue(entry.extras, .midiChannel)
        }

        #expect(foundChannel == 5)
    }

    @Test
    func read_midiVoiceDirectiveInBody_assignsCurrentVoice() throws {
        // The example in §11.2 of the ABC 2.1 standard.
        let abc = """
            X:1
            T:Organ Tune
            L:1/4
            V:Rueckpos
            V:Organo
            K:C
            V:Rueckpos
            %%MIDI voice instrument=53 bank=2
            C D E F|
            V:Organo
            %%MIDI voice instrument=73
            G A B c|
            """
        let wrapper = FileWrapper(regularFileWithContents: Data(abc.utf8))
        let work = try #require(ABC.Importer().read(from: wrapper, as: .abc).first)
        let rueckpos = try namedStandardPart(work, "Rueckpos")
        let organo = try namedStandardPart(work, "Organo")

        #expect(rueckpos.instrumentMap[.zero] == Instrument("Choir Aahs"))
        #expect(organo.instrumentMap[.zero] == Instrument("Piccolo"))

        var banks: [Int?] = []

        for entry in rueckpos.instrumentMap {
            banks.append(intValue(entry.extras, .midiBank))
        }

        for entry in organo.instrumentMap {
            banks.append(intValue(entry.extras, .midiBank))
        }

        #expect(banks == [1, nil])
    }

    @Test
    func read_midiVoiceDirectivesInHeader_namedVoiceWinsOverFallbackAndProgram() throws {
        let abc = """
            X:1
            T:Header Tune
            L:1/4
            %%MIDI program 2 41
            %%MIDI voice Tb instrument=59
            %%MIDI voice instrument=43
            V:Tb
            V:Vc
            K:C
            V:Tb
            C, D, E, F,|
            V:Vc
            C D E F|
            """
        let wrapper = FileWrapper(regularFileWithContents: Data(abc.utf8))
        let work = try #require(ABC.Importer().read(from: wrapper, as: .abc).first)
        let tuba = try namedStandardPart(work, "Tb")
        let cello = try namedStandardPart(work, "Vc")

        #expect(tuba.instrumentMap[.zero] == Instrument("Tuba"))
        #expect(cello.instrumentMap[.zero] == Instrument("Cello"))

        var channels: [Int?] = []

        for entry in tuba.instrumentMap {
            channels.append(intValue(entry.extras, .midiChannel))
        }

        #expect(channels == [2])
    }
}
