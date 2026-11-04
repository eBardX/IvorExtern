// © 2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import IvorModel
import IvorMXL
import Testing
import XestiTools

struct MusicXMLVelocityFunctionsTests {
}

// MARK: -

extension MusicXMLVelocityFunctionsTests {
    @Test(arguments: [(1, 1.11), (40, 44.44), (90, 100.0), (127, 141.11)])
    func convertToMusicXMLEndDynamics_convertsToPercentOfForte(_ velocity: Int, _ percent: Double) {
        let extras = Extras(elements: [Extra(name: Extra.releaseVelocity.name, values: [.int(velocity)])])

        #expect(convertToMusicXMLEndDynamics(extras) == percent)
    }

    @Test(arguments: [nil, 0, 128])
    func convertToMusicXMLEndDynamics_missingOrOutOfRange_returnsNil(_ velocity: Int?) {
        let extras = velocity.map { Extras(elements: [Extra(name: Extra.releaseVelocity.name, values: [.int($0)])]) }

        #expect(convertToMusicXMLEndDynamics(extras) == nil)
    }

    @Test(arguments: [(nil, nil), (0.0, nil), (1.11, 1), (44.44, 40), (100.0, 90), (141.11, 127), (200.0, 127)])
    func convertToReleaseVelocity_convertsEndDynamicsPercent(_ percent: Double?, _ velocity: Int?) {
        let note = MXLNote(content: .regularNote(fullNote: MXLFullNote(isChord: false, content: .rest(MXLRest())),
                                                 duration: MXLPositiveDivisions(intValue: 1).require(),
                                                 tie: []),
                           endDynamics: percent)

        #expect(convertToReleaseVelocity(note) == velocity)
        #expect(convertToAttackVelocity(note) == nil)
    }
}
