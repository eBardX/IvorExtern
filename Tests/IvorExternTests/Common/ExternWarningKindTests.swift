// © 2026 John Gary Pusey (see LICENSE.md)

import IvorExtern
import Testing

struct ExternWarningKindTests {
}

// MARK: -

extension ExternWarningKindTests {
    @Test
    func hashable() {
        let kinds: Set<ExternWarning.Kind> = [.droppedCaesura, .droppedCaesura, .splitArpeggio]

        #expect(kinds.count == 2)
    }

    @Test
    func rawValue_eachCase() {
        #expect(ExternWarning.Kind.droppedCaesura.rawValue == "droppedCaesura")
        #expect(ExternWarning.Kind.droppedExecution.rawValue == "droppedExecution")
        #expect(ExternWarning.Kind.droppedFermata.rawValue == "droppedFermata")
        #expect(ExternWarning.Kind.droppedNonArpeggiate.rawValue == "droppedNonArpeggiate")
        #expect(ExternWarning.Kind.droppedOrnament.rawValue == "droppedOrnament")
        #expect(ExternWarning.Kind.droppedSlash.rawValue == "droppedSlash")
        #expect(ExternWarning.Kind.movedFigureAfterNote.rawValue == "movedFigureAfterNote")
        #expect(ExternWarning.Kind.splitArpeggio.rawValue == "splitArpeggio")
    }

    @Test
    func rawValue_roundTrip() {
        #expect(ExternWarning.Kind(rawValue: "droppedOrnament") == .droppedOrnament)
        #expect(ExternWarning.Kind(rawValue: "movedFigureAfterNote") == .movedFigureAfterNote)
    }

    @Test
    func rawValue_unknownIsNil() {
        #expect(ExternWarning.Kind(rawValue: "droppedEverything") == nil)
    }
}
