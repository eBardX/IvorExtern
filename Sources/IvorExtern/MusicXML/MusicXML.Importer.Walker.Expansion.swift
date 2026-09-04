// © 2026 John Gary Pusey (see LICENSE.md)

internal import IvorMusicXML

// Turns the count-based `<measure-style>` shorthands — `<measure-repeat>` and
// `<multiple-rest>` — into literal content, once per part in document order,
// before the `Plan`'s play order (which may revisit a measure for a repeat)
// ever walks it. Resolving this ahead of the cursor walk, rather than
// threading it through the play order the way upstream's own top-level walk
// threads it through a single linear pass, keeps a `<measure-repeat>` or
// `<multiple-rest>` span's meaning fixed regardless of how many times a
// repeat later replays the measures it covers.
//
// A deliberate correctness note governs when expansion actually fires: the
// MusicXML spec says the music under a `<measure-repeat>` — and the rests
// under a `<multiple-rest>` — is normally *written out* in every covered
// measure, the shorthand being only a display hint. Blindly expanding would
// then double it. So content is synthesized only for a covered measure that
// is genuinely empty; a measure that already carries its own notes or rests
// is resolved as written. `<beat-repeat>` and `<slash>` are display-only
// shorthands with no note-level substance to expand and are left alone, per
// upstream.
extension MusicXML.Importer.Walker {

    internal struct Expansion {

        // MARK: Internal Nested Types

        internal enum Plan {
            case items([MXLMusicItem])
            case syntheticRest
        }

        // MARK: Private Nested Types

        private struct MeasureRepeat {
            fileprivate var length: Int
            fileprivate var offset: Int
            fileprivate var patternStart: Int
        }

        // MARK: Private Instance Properties

        private var measureRepeat: MeasureRepeat?
        private var multipleRestRemaining = 0
    }
}

// MARK: -

extension MusicXML.Importer.Walker.Expansion {

    // MARK: Internal Instance Methods

    internal mutating func plan(_ measure: MXLScorePartwise.Part.Measure,
                                at index: Int,
                                in part: MXLScorePartwise.Part) -> Plan {
        let hasNotes = Self._hasNotes(measure)

        for style in Self._measureStyles(in: measure) {
            switch style {
            case let .measureRepeat(measureRepeat):
                switch measureRepeat.kind {
                case .start:
                    let length = measureRepeat.value ?? 1

                    self.measureRepeat = MeasureRepeat(length: length,
                                                       offset: 0,
                                                       patternStart: index - length)

                case .stop:
                    self.measureRepeat = nil
                }

            case let .multipleRest(multipleRest):
                multipleRestRemaining = multipleRest.value

            case .beatRepeat,
                 .slash:
                break
            }
        }

        if multipleRestRemaining > 0 {
            multipleRestRemaining -= 1

            return hasNotes ? .items(measure.items) : .syntheticRest
        }

        if var active = measureRepeat,
           !hasNotes,
           active.patternStart >= 0 {
            let source = part.measures[active.patternStart + (active.offset % active.length)]

            active.offset += 1
            measureRepeat = active

            return .items(source.items)
        }

        return .items(measure.items)
    }

    // MARK: Private Type Methods

    // A Boolean value indicating whether a measure carries any `<note>` at
    // all (a whole-measure `<rest>` counts — it is a `<note>` in MusicXML).
    // An empty measure is one eligible for shorthand synthesis.
    private static func _hasNotes(_ measure: MXLScorePartwise.Part.Measure) -> Bool {
        measure.items.contains {
            if case .note = $0 { true } else { false }
        }
    }

    // The `<measure-style>` declarations of a measure, gathered across all of
    // its `<attributes>` in document order.
    private static func _measureStyles(in measure: MXLScorePartwise.Part.Measure) -> [MXLMeasureStyle.Content] {
        measure.items.flatMap { item -> [MXLMeasureStyle.Content] in
            guard case let .attributes(attributes) = item
            else { return [] }

            return attributes.measureStyle.map(\.content)
        }
    }
}
