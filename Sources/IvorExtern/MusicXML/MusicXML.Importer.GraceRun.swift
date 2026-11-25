// © 2026 John Gary Pusey (see LICENSE.md)

internal import IvorModel
internal import IvorMXL
internal import IvorTiming
internal import IvorTuning
internal import XestiNumbers

extension MusicXML.Importer {

    // MARK: Internal Nested Types

    // The grace notes a voice has read since its last regular note: a figure
    // once it's known which note it graces. It follows the note before it
    // under MuseScore's rules — a grace note with `steal-time-previous` but
    // no `steal-time-following` and no slash (`followsPrevious`), a grace
    // note ending a slur or wavy line (also `followsPrevious`), or a run left
    // at the end of a measure or before a rest — and otherwise graces the
    // next note.
    internal struct GraceRun {

        // MARK: Internal Instance Properties

        internal var events: [Event] = []
        internal var followsPrevious = false
        internal var isSlashed = false
        internal var isTiedForward = false
    }
}

// MARK: -

extension MusicXML.Importer.GraceRun {

    // MARK: Internal Instance Methods

    //
    // The run as a figure before (or, if `isAfter`, after) a main note lasting `mainDuration`.
    // Each grace note keeps its own timing: time stolen from the main note (`steal-time-following`
    // before it, `steal-time-previous` after it) is `fromMain`, time stolen from the other
    // neighbor is `fromPrevious`, and `make-time` becomes `fromMain` of the same length, as a
    // share of the main note capped at all of it, so no figure changes the work's timeline. A
    // tie from the last grace note ties a figure before into its main note.
    //
    internal func figure(isAfter: Bool,
                         mainDuration: BeatDuration) -> NoteTable<BeatTime, Pitch>.GraceFigure? {
        var figureEvents: [NoteTable<BeatTime, Pitch>.GraceFigure.Event] = []

        for event in events {
            let made = event.makeTime.flatMap { Self._share(of: $0, in: mainDuration) }
            let fromMain = Self._share(isAfter ? event.stealTimePrevious : event.stealTimeFollowing) ?? made
            let fromNeighbor = Self._share(isAfter ? event.stealTimeFollowing : event.stealTimePrevious)
            let execution = NoteTable<BeatTime, Pitch>.GraceExecution(fromPrevious: fromNeighbor, fromMain: fromMain)

            if let figureEvent = NoteTable<BeatTime, Pitch>.GraceFigure.Event(pitches: Array(Set(event.pitches)).sorted(),
                                                                              length: event.length,
                                                                              execution: execution.isEmpty ? nil : execution) {
                figureEvents.append(figureEvent)
            }
        }

        return NoteTable<BeatTime, Pitch>.GraceFigure(events: figureEvents,
                                                      isSlashed: isSlashed,
                                                      isTiedToMainNote: !isAfter && isTiedForward)
    }

    // MARK: Private Type Methods

    private static func _share(_ percent: MXLPercent?) -> NoteTable<BeatTime, Pitch>.Amount? {
        guard let percent
        else { return nil }

        return Proportion(numberValue: Number(numerator: Int((percent * 100).rounded()), denominator: 10_000)).map { .share($0) }
    }

    private static func _share(of duration: BeatDuration,
                               in mainDuration: BeatDuration) -> NoteTable<BeatTime, Pitch>.Amount? {
        guard !mainDuration.numberValue.isZero
        else { return nil }

        return Proportion(numberValue: min(1, duration.numberValue / mainDuration.numberValue)).map { .share($0) }
    }
}

// MARK: - Sendable

extension MusicXML.Importer.GraceRun: Sendable {
}
