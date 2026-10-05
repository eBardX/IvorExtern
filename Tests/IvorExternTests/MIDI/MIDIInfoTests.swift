// © 2026 John Gary Pusey (see LICENSE.md)

import Foundation
@testable import IvorExtern
import IvorMIDI
import IvorModel
import IvorSMF
import IvorTiming
import IvorTuning
import Testing
import XestiNumbers
import XestiTools

struct MIDIInfoTests {
}

// MARK: -

extension MIDIInfoTests {
    @Test
    func convert_metaEvents_populateInfo() throws {
        let key = MIDIData1Value(60)
        let conductor = SMFTrack(events: [.meta(.zero, .copyright(SMFText("(C) 1998 Acme"))),
                                          .meta(.zero, .sequenceTrackName(SMFText("Aubade"))),
                                          .meta(.zero, .text(SMFText("Dedication: For Anna"))),
                                          .meta(.zero, .text(SMFText("Arranged for the festival"))),
                                          .meta(SMFEventTime(480), .text(SMFText("Later text"))),
                                          .meta(SMFEventTime(480), .endOfTrack)])
        let melody = SMFTrack(events: [.meta(.zero, .sequenceTrackName(SMFText("Melody"))),
                                       .meta(.zero, .text(SMFText("Play softly"))),
                                       .meta(.zero, .lyric(SMFText("{@LATIN}{#Title=Dawn Song}{#Composer=J. Smith}"))),
                                       .meta(.zero, .lyric(SMFText("{#Lyrics=A. Poet}{#Artist=The Band}{#}"))),
                                       .meta(.zero, .instrumentName(SMFText("Flauto 1"))),
                                       .midi(.zero, .programChange(MIDIChannel(1), MIDIData1Value(73))),
                                       .midi(.zero, .noteOn(MIDIChannel(1), key, MIDIData1Value(100))),
                                       .midi(SMFEventTime(480), .noteOff(MIDIChannel(1), key, MIDIData1Value(64))),
                                       .meta(SMFEventTime(480), .endOfTrack)])
        let work = try MIDI.Importer().convert(SMFSequence(format: .format1,
                                                           division: .metrical(SMFTickRate(480)),
                                                           tracks: [conductor, melody]))
        let info = work.info
        let part = try #require(keyboardBeatParts(of: work)?.first)
        let entry = try #require(part.instrumentMap.first)

        #expect(info.title == "Aubade")
        #expect(info.subtitles == ["Dawn Song"])
        #expect(info.credits == [Credit(name: "J. Smith", role: .composer),
                                 Credit(name: "A. Poet", role: .lyricist),
                                 Credit(name: "The Band", role: .artist)].compactMap(\.self))
        #expect(info.rights == [RightsNotice(text: "(C) 1998 Acme")].compactMap(\.self))
        #expect(info.dedication == "For Anna")
        #expect(info.remarks == [Remark(text: "Arranged for the festival")].compactMap(\.self))
        #expect(stringValue(entry.extras, .instrumentName) == "Flauto 1")
    }

    @Test
    func convertToMIDIText_nonLatin1_isTransliterated() throws {
        let text = try #require(convertToMIDIText("Café ‘Acme’ — ℗ 1998"))

        #expect(text.stringValue == "Café 'Acme' - (P) 1998")
        #expect(text.bytesValue != nil)
    }

    @Test
    func parseSongInformation_readsTagsInOrder() {
        let tags = parseSongInformation("{@LATIN}{#Title=Yesterday}{#Composer=Someone}{#}")

        #expect(tags.map(\.name) == ["Title", "Composer"])
        #expect(tags.map(\.value) == ["Yesterday", "Someone"])
    }

    @Test
    func roundTrip_info_preservesWhatMIDICanHold() throws {
        let recovered = try roundTrip(_sampleWork(),
                                      exporter: MIDI.Exporter(),
                                      importer: MIDI.Importer(),
                                      fileFormat: .midi)
        let info = recovered.info
        let part = try #require(keyboardBeatParts(of: recovered)?.first)
        let entry = try #require(part.instrumentMap.first)

        #expect(recovered.name == "Aubade")
        #expect(info.title == "Aubade")
        #expect(info.subtitles.isEmpty)
        #expect(info.dedication == "To my teacher\nwith thanks")
        #expect(info.credits.isEmpty)
        #expect(info.rights == [RightsNotice(text: "© 1998 Acme\n(P) 1999 Acme")].compactMap(\.self))
        #expect(info.remarks == [Remark(text: "J. Smith (composer)"),
                                 Remark(text: "history: Written at dawn")].compactMap(\.self))
        #expect(stringValue(entry.extras, .instrumentName) == "Flauto 1")
    }

    @Test
    func write_info_writesCopyrightFirst() throws {
        let sequence = try MIDI.Exporter().convert(_sampleWork())
        let conductor = try #require(sequence.tracks.first)
        let first = try #require(conductor.events.first)

        guard case let .meta(_, .copyright(text)) = first
        else { Issue.record("Expected a Copyright event first"); return }

        #expect(text.stringValue == "© 1998 Acme\n(P) 1999 Acme")
    }
}

// MARK: -

extension MIDIInfoTests {
    private func _sampleWork() -> Work {
        var noteTable = NoteTable<BeatTime, NoteNumber>()
        var instrumentMap = InstrumentMap<BeatTime>()

        noteTable.insert(attack: .zero, duration: BeatDuration(1), pitch: NoteNumber(60))
        instrumentMap.insert(time: .zero,
                             instrument: Instrument("Flute"),
                             extras: Extras(elements: [Extra(name: Extra.instrumentName.name, values: [.string("Flauto 1")])]))

        let part = Part(name: "Melody",
                        noteTable: noteTable,
                        instrumentMap: instrumentMap)

        return Work(name: "Sketch",
                    content: .keyboardBeat([part], TempoMap()),
                    info: Work.Info(title: "Aubade",
                                    subtitles: ["Dawn Song"],
                                    dedication: "To my teacher\nwith thanks",
                                    credits: [Credit(name: "J. Smith", role: .composer)].compactMap(\.self),
                                    rights: [RightsNotice(text: "© 1998 Acme"),
                                             RightsNotice(text: "℗ 1999 Acme")].compactMap(\.self),
                                    remarks: [Remark(text: "Written at dawn", label: "history")].compactMap(\.self)))
    }
}
