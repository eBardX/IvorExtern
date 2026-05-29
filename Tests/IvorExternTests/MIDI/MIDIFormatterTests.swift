// © 2025–2026 John Gary Pusey (see LICENSE.md)

import Foundation
@testable import IvorExtern
import IvorMIDI
import IvorModel
import IvorTiming
import IvorTuning
import Testing
import XestiNumbers
import XestiTools

struct MIDIFormatterTests {
}

// MARK: -

extension MIDIFormatterTests {

    @Test
    func format_minimalSequence_nonEmpty() throws {
        let track = SMFTrack(events: [.meta(.zero, .endOfTrack)])
        let sequence = SMFSequence(format: .format1,
                                   division: .metrical(SMFTickRate(480)),
                                   tracks: [track])
        let data = try MIDI.Formatter().format(sequence)

        #expect(!data.isEmpty)
    }

    @Test
    func format_startsWithMThd() throws {
        let track = SMFTrack(events: [.meta(.zero, .endOfTrack)])
        let sequence = SMFSequence(format: .format1,
                                   division: .metrical(SMFTickRate(480)),
                                   tracks: [track])
        let data = try MIDI.Formatter().format(sequence)

        #expect(data.count >= 4)
        #expect(data[0] == 0x4d)  // 'M'
        #expect(data[1] == 0x54)  // 'T'
        #expect(data[2] == 0x68)  // 'h'
        #expect(data[3] == 0x64)  // 'd'
    }

    @Test
    func format_roundTrip_preservesNoteCount() throws {
        var table = NoteTable<BeatTime, NoteNumber>()

        table.insert(attack: BeatTime(0), duration: BeatDuration(1), pitch: NoteNumber(60))
        table.insert(attack: BeatTime(1), duration: BeatDuration(1), pitch: NoteNumber(62))
        table.insert(attack: BeatTime(2), duration: BeatDuration(1), pitch: NoteNumber(64))

        let part = Part(name: "RoundTrip", noteTable: table)
        let original = Work(name: "RT",
                            content: .keyboardBeat([part],
                                                   TempoMap()))

        let exportedSequence = try MIDI.Converter().convert(original)
        let data = try MIDI.Formatter().format(exportedSequence)

        let parsedSequence = try MIDI.Parser().parse(data)
        let recovered = try MIDI.Converter().convert(parsedSequence)

        guard case let .keyboardBeat(recoveredParts, _) = recovered.content
        else { Issue.record("Unexpected content type"); return }

        var totalNotes = 0

        recoveredParts.forEach { part in
            part.noteTable.forEach { _, _, _, _, _ in
                totalNotes += 1
            }
        }

        #expect(totalNotes == 3)
    }
}
