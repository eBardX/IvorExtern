// © 2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import IvorMusicXML
import Testing
import XestiNumbers

struct MusicXMLImporterRhythmTests {
}

// MARK: -

extension MusicXMLImporterRhythmTests {
    @Test
    func resolve_nilActiveDivisions_throws() {
        let rhythm = MusicXML.Importer.Rhythm()

        #expect(throws: (any Error).self) {
            try rhythm.resolve(count: 1,
                               activeDivisions: nil,
                               context: "note")
        }
    }

    @Test
    func resolve_validCount() throws {
        let rhythm = MusicXML.Importer.Rhythm()

        let duration = try rhythm.resolve(count: 2,
                                          activeDivisions: 4,
                                          context: "note")

        #expect(duration.numberValue == Number(numerator: 2,
                                               denominator: 16))
    }

    @Test
    func resolve_zeroActiveDivisions_throws() {
        let rhythm = MusicXML.Importer.Rhythm()

        #expect(throws: (any Error).self) {
            try rhythm.resolve(count: 1,
                               activeDivisions: 0,
                               context: "note")
        }
    }

    @Test
    func wholeMeasureDuration_compositeSignature() throws {
        let rhythm = MusicXML.Importer.Rhythm()
        let time = MXLTime(content: .timeSignature([MXLTimeSignature(beats: "2+3",
                                                                     beatType: "8")],
                                                   interchangeable: nil))

        let duration = try rhythm.wholeMeasureDuration(from: time,
                                                       context: "measure")

        #expect(duration.numberValue == Number(numerator: 5,
                                               denominator: 8))
    }

    @Test
    func wholeMeasureDuration_invalidBeatsField_throws() {
        let rhythm = MusicXML.Importer.Rhythm()
        let time = MXLTime(content: .timeSignature([MXLTimeSignature(beats: "four",
                                                                     beatType: "4")],
                                                   interchangeable: nil))

        #expect(throws: (any Error).self) {
            try rhythm.wholeMeasureDuration(from: time,
                                            context: "measure")
        }
    }

    @Test
    func wholeMeasureDuration_nilTime_throws() {
        let rhythm = MusicXML.Importer.Rhythm()

        #expect(throws: (any Error).self) {
            try rhythm.wholeMeasureDuration(from: nil,
                                            context: "measure")
        }
    }

    @Test
    func wholeMeasureDuration_senzaMisura_throws() {
        let rhythm = MusicXML.Importer.Rhythm()
        let time = MXLTime(content: .senzaMisura(""))

        #expect(throws: (any Error).self) {
            try rhythm.wholeMeasureDuration(from: time,
                                            context: "measure")
        }
    }

    @Test
    func wholeMeasureDuration_simpleSignature() throws {
        let rhythm = MusicXML.Importer.Rhythm()
        let time = MXLTime(content: .timeSignature([MXLTimeSignature(beats: "4",
                                                                     beatType: "4")],
                                                   interchangeable: nil))

        let duration = try rhythm.wholeMeasureDuration(from: time,
                                                       context: "measure")

        #expect(duration.numberValue == Number(numerator: 4,
                                               denominator: 4))
    }

    @Test
    func wholeMeasureDuration_zeroBeatType_throws() {
        let rhythm = MusicXML.Importer.Rhythm()
        let time = MXLTime(content: .timeSignature([MXLTimeSignature(beats: "4",
                                                                     beatType: "0")],
                                                   interchangeable: nil))

        #expect(throws: (any Error).self) {
            try rhythm.wholeMeasureDuration(from: time,
                                            context: "measure")
        }
    }

    @Test
    func wholeMeasureDuration_zeroTotalBeats_throws() {
        let rhythm = MusicXML.Importer.Rhythm()
        let time = MXLTime(content: .timeSignature([MXLTimeSignature(beats: "0",
                                                                     beatType: "4")],
                                                   interchangeable: nil))

        #expect(throws: (any Error).self) {
            try rhythm.wholeMeasureDuration(from: time,
                                            context: "measure")
        }
    }
}
