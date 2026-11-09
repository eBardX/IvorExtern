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
