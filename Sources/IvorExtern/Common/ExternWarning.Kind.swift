// © 2026 John Gary Pusey (see LICENSE.md)

extension ExternWarning {

    // MARK: Public Nested Types

    /// What an ``ExternWarning`` reports was dropped or approximated.
    public enum Kind: String {

        /// A caesura was dropped: the format has no caesura.
        case droppedCaesura

        /// How an ornament, grace figure, arpeggio or fermata is played — its execution — was
        /// dropped, keeping the sign: the format can’t say it.
        case droppedExecution

        /// A fermata mark that starts at no note or rest was dropped: the format can only put a
        /// fermata on a note or rest.
        case droppedFermata

        /// A MusicXML `<non-arpeggiate>` bracket was dropped: it has no effect on playback, and
        /// the model doesn’t keep it.
        case droppedNonArpeggiate

        /// An ornament with no standard sign, such as a lower trill, was dropped: the format can
        /// only write signed ornaments.
        case droppedOrnament

        /// A grace figure lost its slash, the mark of an acciaccatura: the format has none.
        case droppedSlash

        /// A grace figure after a note was written before the next note instead: the format has
        /// no figure after a note.
        case movedFigureAfterNote

        /// A rolled chord spanning parts was written as a roll in each part: the format rolls a
        /// chord within one part only.
        case splitArpeggio
    }
}

// MARK: - Hashable

extension ExternWarning.Kind: Hashable {
}

// MARK: - Sendable

extension ExternWarning.Kind: Sendable {
}
