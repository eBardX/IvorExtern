// © 2026 John Gary Pusey (see LICENSE.md)

internal import IvorModel
internal import IvorMXL
internal import IvorTiming
internal import IvorTuning
internal import XestiNumbers
internal import XestiTools

// One piece of a part as MusicXML items: a rest, or a note or chord with the
// grace notes before and after it (see `MusicXML.Exporter.OrnamentWriter`).
extension MusicXML.Exporter {

    // MARK: Internal Type Methods

    // The note/chord or rest item(s) covering one boundary interval.
    // A note or chord comes with the grace notes of a figure before it and of
    // one after it, in document order.
    internal static func makeSegmentItems(slice: ExportSlice,
                                          divisions: Int,
                                          writer: OrnamentWriter) throws(MusicXML.Error) -> [MXLMusicItem] {
        let segmentDuration = BeatDuration(slice.end.numberValue - slice.start.numberValue)
        let mxlDuration = convertToMusicXMLDivisions(segmentDuration, divisions).require()

        guard !slice.tones.isEmpty
        else {
            return [.note(MXLNote(content: .regularNote(fullNote: MXLFullNote(isChord: false, content: .rest(MXLRest())),
                                                        duration: mxlDuration,
                                                        tie: []),
                                  notations: writer.restNotations(slice)))]
        }

        let attackedTones = slice.attackedTones
        var items = try writer.graceBeforeItems(attackedTones)

        if let tremoloItems = try writer.twoNoteTremoloItems(slice,
                                                             duration: segmentDuration,
                                                             divisions: divisions) {
            items += tremoloItems
        } else {
            items += try _makeNoteItems(slice: slice,
                                        duration: mxlDuration,
                                        segmentDuration: segmentDuration,
                                        writer: writer)
        }

        items += try writer.graceAfterItems(slice.releasedTones)

        return items
    }

    // MARK: Private Type Methods

    // One `<note>` per tone of `slice` — the first carrying `isChord:
    // false`, every later one `isChord: true`, per the MusicXML convention
    // that a chord's duration is repeated on each of its notes even though
    // only the first one advances the musical position within the measure.
    // Each tone has its own tie state: a stop when it was tied in from the
    // slice before, and a start when it continues into the next one. Both
    // the sound tie (`MXLTie`, inside `content`) and the notated tie
    // (`MXLTied`, inside `notations`) are written together, since MusicXML
    // keeps the two independent and an importer or renderer may read either.
    // The tones attacked here carry the articulation/ornament/technical/
    // fingering and slur-start items of every tone attacked here (a
    // tied-in continuation never repeats them), and the tones released here
    // the slur-end items of every tone released here — the same gating
    // `ABC.Exporter`/`Guido.Exporter` use, adapted to MusicXML's one-
    // `<notations>`-block-per-note shape instead of a symbol stream. See
    // `ABC.Exporter._unionElements(_:)` for why a chord-wide union, not a
    // per-tone split, is this vocabulary's accepted chord simplification.
    // A tone's own `releaseVelocity` is the exception: it's per-note data,
    // not a marker, so it's written as that tone's `end-dynamics`, where it
    // is released.
    private static func _makeNoteItems(slice: ExportSlice,
                                       duration: MXLPositiveDivisions,
                                       segmentDuration: BeatDuration,
                                       writer: OrnamentWriter) throws(MusicXML.Error) -> [MXLMusicItem] {
        var items: [MXLMusicItem] = []
        let attackElements = slice.attackedTones.compactMap { $0.extras?.elements }.flatMap { $0 }
        let releaseElements = slice.releasedTones.compactMap { $0.extras?.elements }.flatMap { $0 }

        for (index, tone) in slice.tones.enumerated() {
            let mxlPitch = try convertToMusicXMLPitch(tone.pitch)
            let isAttacked = !slice.isTiedIn(tone)
            let isReleased = !slice.continues(tone)

            var ties: [MXLTie] = []
            var notationItems: [MXLNotations.Item] = []

            if !isAttacked || writer.isTiedFromFigure(tone, in: slice.attackedTones) {
                ties.append(MXLTie(kind: .stop))
                notationItems.append(.tied(MXLTied(kind: .stop)))
            }

            if !isReleased {
                ties.append(MXLTie(kind: .start))
                notationItems.append(.tied(MXLTied(kind: .start)))
            }

            if isAttacked {
                notationItems += convertToMusicXMLNotationItems(attackElements)
                notationItems += convertToMusicXMLSlurStartItems(attackElements)
            }

            if isReleased {
                notationItems += convertToMusicXMLSlurEndItems(releaseElements)
            }

            notationItems += writer.notationItems(for: tone, in: slice, duration: segmentDuration, includesOrnament: true)

            let note = MXLNote(content: .regularNote(fullNote: MXLFullNote(isChord: index > 0, content: .pitch(mxlPitch)),
                                                     duration: duration,
                                                     tie: ties),
                               notations: notationItems.isEmpty ? [] : [MXLNotations(items: notationItems)],
                               endDynamics: isReleased ? convertToMusicXMLEndDynamics(tone.extras) : nil)

            items.append(.note(note))
        }

        return items
    }
}
