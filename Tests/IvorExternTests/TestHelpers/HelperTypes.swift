// © 2026 John Gary Pusey (see LICENSE.md)

import IvorMXL

// MARK: -

// One exported MusicXML `<direction>` that writes a pedal: its `<pedal>`
// marks and its `<sound>`.
internal struct ExportedPedalDirection {
    internal let pedals: [MXLPedal]
    internal let sound: MXLSound?

    internal var damper: MXLYesNoNumber? {
        sound?.damperPedal
    }

    internal var marks: [MXLPedal.Kind] {
        pedals.map(\.kind)
    }

    internal var soft: MXLYesNoNumber? {
        sound?.softPedal
    }
}

// One regular `<note>` an exporter wrote: its duration in divisions,
// whether it continues a chord, its pitch step (or `"rest"`), and the kinds
// of its ties.
internal struct ExportedMXLNote {
    internal let duration: Int
    internal let isChord: Bool
    internal let step: String
    internal let ties: [MXLStartStop]
}

// One fermata marker meta event in an exported Standard MIDI File's
// conductor track: its tick and text.
internal struct MIDIFermataMarker {
    internal let tick: UInt
    internal let text: String
}

// MARK: - Equatable

extension MIDIFermataMarker: Equatable {
}
