// © 2025–2026 John Gary Pusey (see LICENSE.md)

import Foundation
@testable import IvorExtern
import IvorModel
import IvorTiming
import Testing

struct JohnnySonicExporterTests {
}

// MARK: -

extension JohnnySonicExporterTests {
    @Test
    func write_multipleWorks_throws() {
        let works = [Work(name: "A", content: .keyboardBeat([], TempoMap())),
                     Work(name: "B", content: .keyboardBeat([], TempoMap()))]

        #expect(throws: (any Error).self) {
            try JohnnySonic.Exporter().write(works: works, as: .dkm)
        }
    }

    @Test
    func write_singleKeyboardBeatWork_returnsRegularFile() throws {
        let work = Work(name: "Test", content: .keyboardBeat([], TempoMap()))
        let wrapper = try JohnnySonic.Exporter().write(works: [work], as: .dkm)

        #expect(wrapper.isRegularFile)
        #expect(wrapper.regularFileContents?.isEmpty == false)
    }

    @Test
    func write_unsupportedFormat_throws() {
        let work = Work(name: "Test", content: .keyboardBeat([], TempoMap()))

        #expect(throws: (any Error).self) {
            try JohnnySonic.Exporter().write(works: [work], as: .abc)
        }
    }

    @Test
    func writableFileFormats_containsDKM() {
        #expect(JohnnySonic.Exporter().writableFileFormats.contains(.dkm))
    }
}
