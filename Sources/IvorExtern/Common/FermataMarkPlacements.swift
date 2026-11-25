// © 2026 John Gary Pusey (see LICENSE.md)

internal import IvorModel
internal import IvorTiming

//
// Where a notation exporter writes each fermata mark of a part (resolution 18 of the grace-notes
// plan): before the bar line it ends at, by the bar line's time, or else on the note or rest that
// starts at its time. A mark at no event's start is dropped, and so is every caesura, unless the
// format has them (`keepsCaesuras`, for MusicXML); a mark's execution is dropped too.
//
internal struct FermataMarkPlacements {

    // MARK: Internal Initializers

    internal init(_ markTable: PartMarkTable<BeatTime>,
                  sliceStarts: Set<BeatTime>,
                  barTimes: Set<BeatTime>,
                  keepsCaesuras: Bool = false,
                  report: (ExternWarning.Kind) -> Void) {
        var atStart: [BeatTime: Fermata<BeatTime>] = [:]
        var beforeBar: [BeatTime: Fermata<BeatTime>] = [:]
        var caesuras: Set<BeatTime> = []

        for entry in markTable {
            switch entry.mark {
            case let .caesura(execution) where keepsCaesuras:
                caesuras.insert(entry.time)

                if execution != nil {
                    report(.droppedExecution)
                }

            case .caesura:
                report(.droppedCaesura)

            case let .fermata(fermata, span):
                let end = entry.time + span.duration

                if fermata.execution != nil {
                    report(.droppedExecution)
                }

                if barTimes.contains(end) {
                    beforeBar[end] = beforeBar[end] ?? fermata
                } else if sliceStarts.contains(entry.time) {
                    atStart[entry.time] = atStart[entry.time] ?? fermata
                } else {
                    report(.droppedFermata)
                }
            }
        }

        self.atStart = atStart
        self.beforeBar = beforeBar
        self.caesuras = caesuras
    }

    // MARK: Internal Instance Properties

    // The marks written on the note or rest starting at their time, by that time.
    internal let atStart: [BeatTime: Fermata<BeatTime>]

    // The marks written before the bar line they end at, by the bar line's time.
    internal let beforeBar: [BeatTime: Fermata<BeatTime>]

    // The caesuras' times, if `keepsCaesuras`.
    internal let caesuras: Set<BeatTime>
}

// MARK: - Sendable

extension FermataMarkPlacements: Sendable {
}
