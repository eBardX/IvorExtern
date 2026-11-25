// © 2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import IvorModel
import IvorMXL
import IvorTiming
import IvorTuning
import Testing

struct MusicXMLOrnamentFunctionsTests {
}

// MARK: -

extension MusicXMLOrnamentFunctionsTests {
    @Test
    func convertToAccidental_standardMarks() {
        #expect(convertToAccidental(.doubleSharp) == .doubleSharp)
        #expect(convertToAccidental(.flat) == .flat)
        #expect(convertToAccidental(.flatFlat) == .doubleFlat)
        #expect(convertToAccidental(.natural) == .natural)
        #expect(convertToAccidental(.sharp) == .sharp)
        #expect(convertToAccidental(.sharpSharp) == .doubleSharp)
    }

    @Test
    func convertToAccidental_unsupportedMark_isNil() {
        #expect(convertToAccidental(.arrowDown) == nil)
        #expect(convertToAccidental(.doubleSharpUp) == nil)
    }

    @Test
    func convertToBeatDuration_dots() {
        #expect(convertToBeatDuration(kind: .quarter, dots: 1) == dur(3, 8))
        #expect(convertToBeatDuration(kind: .quarter, dots: 2) == dur(7, 16))
    }

    @Test
    func convertToBeatDuration_eachKind() {
        #expect(convertToBeatDuration(kind: .maxima, dots: 0) == dur(8))
        #expect(convertToBeatDuration(kind: .long, dots: 0) == dur(4))
        #expect(convertToBeatDuration(kind: .breve, dots: 0) == dur(2))
        #expect(convertToBeatDuration(kind: .whole, dots: 0) == dur(1))
        #expect(convertToBeatDuration(kind: .half, dots: 0) == dur(1, 2))
        #expect(convertToBeatDuration(kind: .quarter, dots: 0) == dur(1, 4))
        #expect(convertToBeatDuration(kind: .eighth, dots: 0) == dur(1, 8))
        #expect(convertToBeatDuration(kind: .n16th, dots: 0) == dur(1, 16))
        #expect(convertToBeatDuration(kind: .n32nd, dots: 0) == dur(1, 32))
        #expect(convertToBeatDuration(kind: .n64th, dots: 0) == dur(1, 64))
        #expect(convertToBeatDuration(kind: .n128th, dots: 0) == dur(1, 128))
        #expect(convertToBeatDuration(kind: .n256th, dots: 0) == dur(1, 256))
        #expect(convertToBeatDuration(kind: .n512th, dots: 0) == dur(1, 512))
        #expect(convertToBeatDuration(kind: .n1024th, dots: 0) == dur(1, 1_024))
    }

    @Test
    func convertToBeatDuration_negativeDots_areIgnored() {
        #expect(convertToBeatDuration(kind: .half, dots: -1) == dur(1, 2))
    }

    @Test
    func convertToFermataShape_eachShape() {
        #expect(convertToFermataShape(.angled) == .short)
        #expect(convertToFermataShape(.doubleAngled) == .veryShort)
        #expect(convertToFermataShape(.doubleSquare) == .veryLong)
        #expect(convertToFermataShape(.square) == .long)
    }

    @Test
    func convertToFermataShape_otherShapes_areNormal() {
        #expect(convertToFermataShape(.curlew) == .normal)
        #expect(convertToFermataShape(.doubleDot) == .normal)
        #expect(convertToFermataShape(.empty) == .normal)
        #expect(convertToFermataShape(.halfCurve) == .normal)
        #expect(convertToFermataShape(.normal) == .normal)
    }

    @Test
    func convertToFlagCount_eachKind() {
        #expect(convertToFlagCount(kind: .quarter) == 0)
        #expect(convertToFlagCount(kind: .whole) == 0)
        #expect(convertToFlagCount(kind: .eighth) == 1)
        #expect(convertToFlagCount(kind: .n16th) == 2)
        #expect(convertToFlagCount(kind: .n32nd) == 3)
        #expect(convertToFlagCount(kind: .n64th) == 4)
        #expect(convertToFlagCount(kind: .n128th) == 5)
        #expect(convertToFlagCount(kind: .n256th) == 6)
        #expect(convertToFlagCount(kind: .n512th) == 7)
        #expect(convertToFlagCount(kind: .n1024th) == 8)
    }

    @Test
    func convertToMusicXMLAccidentalValue_eachAccidental() {
        #expect(convertToMusicXMLAccidentalValue(.doubleFlat) == .flatFlat)
        #expect(convertToMusicXMLAccidentalValue(.doubleSharp) == .doubleSharp)
        #expect(convertToMusicXMLAccidentalValue(.flat) == .flat)
        #expect(convertToMusicXMLAccidentalValue(.natural) == .natural)
        #expect(convertToMusicXMLAccidentalValue(.sharp) == .sharp)
    }

    @Test
    func convertToMusicXMLAccidentalValue_roundTrip() {
        for accidental: Pitch.Accidental in [.doubleFlat, .doubleSharp, .flat, .natural, .sharp] {
            #expect(convertToAccidental(convertToMusicXMLAccidentalValue(accidental)) == accidental)
        }
    }

    @Test
    func convertToMusicXMLFermataShape_roundTrip() {
        for shape: FermataShape in [.long, .normal, .short, .veryLong, .veryShort] {
            #expect(convertToFermataShape(convertToMusicXMLFermataShape(shape)) == shape)
        }
    }

    @Test
    func convertToMusicXMLNoteKind_dotted() {
        let written = convertToMusicXMLNoteKind(dur(3, 8))

        #expect(written?.kind == .quarter)
        #expect(written?.dots == 1)
    }

    @Test
    func convertToMusicXMLNoteKind_doubleDotted() {
        let written = convertToMusicXMLNoteKind(dur(7, 8))

        #expect(written?.kind == .half)
        #expect(written?.dots == 2)
    }

    @Test
    func convertToMusicXMLNoteKind_plain() {
        let written = convertToMusicXMLNoteKind(dur(1, 4))

        #expect(written?.kind == .quarter)
        #expect(written?.dots == 0)
    }

    @Test
    func convertToMusicXMLNoteKind_unwritable_isNil() {
        #expect(convertToMusicXMLNoteKind(dur(5, 8)) == nil)
        #expect(convertToMusicXMLNoteKind(dur(1, 3)) == nil)
    }
}
