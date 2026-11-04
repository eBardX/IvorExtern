// © 2026 John Gary Pusey (see LICENSE.md)

import IvorABC
@testable import IvorExtern
import IvorModel
import Testing
import XestiTools

struct ABCVoiceInstrumentTests {
}

// MARK: -

extension ABCVoiceInstrumentTests {
    @Test
    func init_storesProperties() throws {
        let instrument = try #require(Instrument(stringValue: "Flute"))
        let voiceID = try #require(ABCVoice.ID(stringValue: "T1"))
        let voiceInstrument = ABC.VoiceInstrument(bank: 2,
                                                  instrument: instrument,
                                                  program: 74,
                                                  voiceID: voiceID)

        #expect(voiceInstrument.bank == 2)
        #expect(voiceInstrument.instrument == instrument)
        #expect(voiceInstrument.program == 74)
        #expect(voiceInstrument.voiceID == voiceID)
    }

    @Test
    func init_withoutBankOrVoice() throws {
        let instrument = try #require(Instrument(stringValue: "Flute"))
        let voiceInstrument = ABC.VoiceInstrument(bank: nil,
                                                  instrument: instrument,
                                                  program: 74,
                                                  voiceID: nil)

        #expect(voiceInstrument.bank == nil)
        #expect(voiceInstrument.voiceID == nil)
    }
}
