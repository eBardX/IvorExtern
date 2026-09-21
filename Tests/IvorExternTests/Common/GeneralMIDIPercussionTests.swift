// © 2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import Testing

struct GeneralMIDIPercussionTests {
}

// MARK: -

extension GeneralMIDIPercussionTests {
    @Test
    func generalMIDIPercussionName_acousticSnareNote_returnsAcousticSnare() {
        #expect(generalMIDIPercussionName(note: 38) == "Acoustic Snare")
    }

    @Test
    func generalMIDIPercussionName_unassignedNote_returnsFallback() {
        #expect(generalMIDIPercussionName(note: 10) == "Percussion 10")
    }

    @Test
    func generalMIDIPercussionName_outOfRangeNote_returnsFallback() {
        #expect(generalMIDIPercussionName(note: 128) == "Percussion 128")
    }

    @Test
    func generalMIDIPercussionNote_acousticSnare_returns38() {
        #expect(generalMIDIPercussionNote(name: "Acoustic Snare") == 38)
    }

    @Test
    func generalMIDIPercussionNote_caseAndWhitespaceInsensitive_matches() {
        #expect(generalMIDIPercussionNote(name: "  acoustic   snare ") == 38)
    }

    @Test
    func generalMIDIPercussionNote_fallbackForm_roundTrips() {
        #expect(generalMIDIPercussionNote(name: "Percussion 10") == 10)
    }

    @Test
    func generalMIDIPercussionNote_unrecognizedName_returnsNil() {
        #expect(generalMIDIPercussionNote(name: "Kazoo") == nil)
    }
}
