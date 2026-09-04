// © 2026 John Gary Pusey (see LICENSE.md)

internal import IvorABC

// One musical event awaiting commit to a `Context`'s `noteTable` — the
// walker's own currency, replacing the fully-resolved event type this
// importer used to walk. Only the three cases that can ever reach the note
// table survive here; every other
// `ABCSymbol`/`ABCField` case is either state (key, meter, unit note length,
// tempo, voice) consumed directly by `ABC.Importer.Walker`, or dropped
// outright.
extension ABC {

    // MARK: Internal Nested Types

    internal enum Event {
        case chord(Chord)
        case note(Note)
        case rest(Rest)
    }
}

// MARK: -

extension ABC.Event {

    // MARK: Internal Instance Properties

    // The tie from this event to whatever follows, if any. A rest is never
    // tied.
    internal var tie: ABCTie? {
        switch self {
        case let .chord(chord):
            chord.tie

        case let .note(note):
            note.tie

        case .rest:
            nil
        }
    }
}

// MARK: - Equatable

extension ABC.Event: Equatable {
}

// MARK: - Sendable

extension ABC.Event: Sendable {
}
