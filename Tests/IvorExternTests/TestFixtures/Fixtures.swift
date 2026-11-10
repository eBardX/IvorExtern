// © 2026 John Gary Pusey (see LICENSE.md)

import Foundation
@testable import IvorExtern
import IvorMIDI
import IvorSMF
import XestiTools

// Source files that use every pedal mark each format has, for the pedal
// round-trip tests. They are built here rather than kept as files, as the
// rest of this suite's inputs are.
internal enum Fixtures {
}

// MARK: -

extension Fixtures {

    // MARK: Internal Type Properties

    // Damper pedal only: down, up and a re-pedal on the third beat.
    static let pedalABC = """
        X:1
        T:Pedals
        M:4/4
        L:1/4
        K:C
        !ped!C D !ped-up!!ped!E !ped-up!F|]
        """

    // Damper pedal only: down, up and a re-pedal on the third beat.
    static let pedalGuido = "[ \\pedalOn c d \\pedalOff \\pedalOn e \\pedalOff f ]"

    // Every `<pedal>` type and every `<sound>` pedal attribute: the damper
    // goes down, is re-pedaled (`change`), drops to half (`<sound>`), and
    // comes up; the sostenuto (`number="2"`) overlaps it; the soft pedal is
    // set by `<sound>` alone; and `discontinue`/`resume`/`continue` leave the
    // level alone.
    static let pedalMusicXML = """
        <?xml version="1.0" encoding="UTF-8"?>
        <score-partwise version="4.0">
          <part-list><score-part id="P1"><part-name>Piano</part-name></score-part></part-list>
          <part id="P1">
            <measure number="1">
              <attributes><divisions>1</divisions></attributes>
              <direction><direction-type><pedal type="start"/></direction-type></direction>
              <sound soft-pedal="yes"/>
              <note><pitch><step>C</step><octave>4</octave></pitch><duration>1</duration><type>quarter</type></note>
              <direction><direction-type><pedal type="change"/></direction-type></direction>
              <direction><direction-type><pedal type="sostenuto" number="2"/></direction-type></direction>
              <note><pitch><step>D</step><octave>4</octave></pitch><duration>1</duration><type>quarter</type></note>
              <sound damper-pedal="50" soft-pedal="no"/>
              <direction><direction-type><pedal type="discontinue"/></direction-type></direction>
              <note><pitch><step>E</step><octave>4</octave></pitch><duration>1</duration><type>quarter</type></note>
              <direction><direction-type><pedal type="resume"/></direction-type></direction>
              <direction><direction-type><pedal type="continue"/></direction-type></direction>
              <direction><direction-type><pedal type="stop"/></direction-type></direction>
              <direction><direction-type><pedal type="stop" number="2"/></direction-type></direction>
              <note><pitch><step>F</step><octave>4</octave></pitch><duration>1</duration><type>quarter</type></note>
            </measure>
          </part>
        </score-partwise>
        """

    // MARK: Internal Type Methods

    // One channel-1 track, 480 ticks per beat, with a note held from 0 to 2
    // beats; half-pedaling on CC 64 (with a re-pedal at one tick), and switch
    // values (0/127) on CC 66–68.
    static func pedalMIDI() throws -> Data {
        let channel = MIDIChannel(1)
        let key = MIDIData1Value(60)
        let controls: [(UInt, MIDIController, UInt)] = [(0, .sustain, 0),
                                                        (0, .sostenuto, 127),
                                                        (0, .legato, 127),
                                                        (120, .sustain, 40),
                                                        (240, .sustain, 64),
                                                        (360, .sustain, 100),
                                                        (480, .sustain, 127),
                                                        (480, .softPedal, 127),
                                                        (600, .sustain, 64),
                                                        (720, .sustain, 0),
                                                        (720, .sustain, 127),
                                                        (720, .sostenuto, 0),
                                                        (840, .softPedal, 0),
                                                        (960, .sustain, 0),
                                                        (960, .legato, 0)]
        var events: [SMFEvent] = [.midi(.zero, .noteOn(channel, key, MIDIData1Value(100)))]

        for (tick, controller, value) in controls {
            events.append(.midi(SMFEventTime(tick), .controlChange(channel, controller, MIDIData1Value(clamping: value))))
        }

        events.append(.midi(SMFEventTime(960), .noteOff(channel, key, MIDIData1Value(64))))

        return try MIDI.Formatter().format(SMFSequence(format: .format1,
                                                       division: .metrical(SMFTickRate(480)),
                                                       tracks: [SMFTrack(events: events)]))
    }
}
